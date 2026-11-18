//! Home.io Bridge: lets Home.io on a phone read and set how much later or earlier each speaker model plays.
//!
//! Only when `HOMEIO_BRIDGE_PORT` is set (the Home Assistant add-on sets it; on a Mac the Home.io Bridge app answers
//! instead). A very small HTTP, announced on the network as `_homeio-bridge._tcp`:
//!   GET  /speakers -> {"speakers":[{"name":"Kitchen Display","model":"Google Nest Hub","delay":0,"synced":true}]}
//!   POST /delay {"model":"Google Nest Hub","delay":40} -> the same list
//! A delay is all it can change, and only within 500 ms either way.

use std::sync::Arc;

use axum::extract::State;
use axum::http::StatusCode;
use axum::routing::{get, post};
use axum::{Json, Router};
use serde::Deserialize;
use serde_json::{Value, json};

use crate::audio::sync::{is_calibrated, owner_delay_ms, set_owner_delay_ms};
use crate::registry::DeviceRegistry;

const SERVICE: &str = "_homeio-bridge._tcp.local.";

#[derive(Deserialize)]
struct Asked {
  model: String,
  delay: i64,
}

fn speakers(registry: &DeviceRegistry) -> Json<Value> {
  let mut list: Vec<_> = registry.list_present();
  list.sort_by(|a, b| a.name.cmp(&b.name));
  let speakers: Vec<Value> = list
    .iter()
    .map(|dev| {
      json!({
        "name": dev.name,
        "model": dev.model,
        "delay": owner_delay_ms(&dev.model),
        "synced": is_calibrated(&dev.model),
      })
    })
    .collect();
  Json(json!({ "speakers": speakers }))
}

async fn get_speakers(State(registry): State<Arc<DeviceRegistry>>) -> Json<Value> {
  speakers(&registry)
}

async fn post_delay(
  State(registry): State<Arc<DeviceRegistry>>,
  Json(asked): Json<Asked>,
) -> Result<Json<Value>, StatusCode> {
  if !is_calibrated(&asked.model) {
    return Err(StatusCode::BAD_REQUEST);
  }
  set_owner_delay_ms(&asked.model, asked.delay).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
  Ok(speakers(&registry))
}

/// Serves until the process ends. Returns at once when `HOMEIO_BRIDGE_PORT` is not set.
pub(crate) async fn serve(registry: Arc<DeviceRegistry>) {
  let Some(port) = std::env::var("HOMEIO_BRIDGE_PORT").ok().and_then(|text| text.parse::<u16>().ok()) else {
    return;
  };
  let listener = match tokio::net::TcpListener::bind(("0.0.0.0", port)).await {
    Ok(listener) => listener,
    Err(err) => {
      tracing::warn!(port, %err, "Home.io delay service could not listen");
      return;
    },
  };
  let _announced = announce(port);
  tracing::info!(port, "Home.io delay service listening");
  let app = Router::new()
    .route("/speakers", get(get_speakers))
    .route("/delay", post(post_delay))
    .with_state(registry);
  if let Err(err) = axum::serve(listener, app).await {
    tracing::warn!(%err, "Home.io delay service stopped");
  }
}

/// Announces the service for as long as the returned daemon is kept.
#[cfg(target_os = "linux")]
fn announce(port: u16) -> Option<mdns_sd::ServiceDaemon> {
  let host = std::fs::read_to_string("/etc/hostname")
    .ok()
    .map(|text| text.trim().to_owned())
    .filter(|name| !name.is_empty())
    .unwrap_or_else(|| "homeio-bridge".to_owned());
  let daemon = mdns_sd::ServiceDaemon::new().ok()?;
  let service = mdns_sd::ServiceInfo::new(
    SERVICE,
    "Home.io Bridge",
    &format!("{host}.local."),
    "",
    port,
    std::collections::HashMap::<String, String>::new(),
  )
  .ok()?
  .enable_addr_auto();
  match daemon.register(service) {
    Ok(()) => Some(daemon),
    Err(err) => {
      tracing::warn!(%err, "Home.io delay service could not announce itself");
      None
    },
  }
}

/// On a Mac the Home.io Bridge app announces and answers; this is for trying the HTTP by hand.
#[cfg(not(target_os = "linux"))]
fn announce(_port: u16) -> Option<()> {
  let _ = SERVICE;
  None
}
