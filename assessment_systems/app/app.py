"""
Simple health-check / info API built with Flask.
Demonstrates:
  - /health  – liveness probe endpoint
  - /ready   – readiness probe endpoint
  - /         – application info (reads VERSION env var)
  - /secret  – proves secret injection from Key Vault CSI driver
"""

import os
import socket
from flask import Flask, jsonify

app = Flask(__name__)

APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
APP_ENV     = os.getenv("APP_ENV", "production")
HOSTNAME    = socket.gethostname()


@app.route("/", methods=["GET"])
def index():
    return jsonify({
        "application": "AKS Assessment App",
        "version":     APP_VERSION,
        "environment": APP_ENV,
        "hostname":    HOSTNAME,
        "status":      "running",
    })


@app.route("/health", methods=["GET"])
def health():
    """Kubernetes liveness probe."""
    return jsonify({"status": "healthy"}), 200


@app.route("/ready", methods=["GET"])
def ready():
    """Kubernetes readiness probe."""
    return jsonify({"status": "ready"}), 200


@app.route("/secret", methods=["GET"])
def secret():
    """
    Reads a secret mounted as a file by the CSI Secret Store Driver.
    The secret file path is /mnt/secrets/app-db-password (see SecretProviderClass).
    This endpoint confirms secrets are correctly injected – never log actual values.
    """
    secret_path = "/mnt/secrets/app-db-password"
    try:
        with open(secret_path, "r") as f:
            _ = f.read()  # read but do NOT expose value
        return jsonify({"secret_mounted": True, "path": secret_path}), 200
    except FileNotFoundError:
        return jsonify({"secret_mounted": False, "path": secret_path}), 404


if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    app.run(host="0.0.0.0", port=port, debug=False)
