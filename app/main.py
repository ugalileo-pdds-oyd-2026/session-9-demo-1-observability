import logging
import os

from flask import Flask, jsonify

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
    handlers=[logging.StreamHandler()],
)
logger = logging.getLogger(__name__)

app = Flask(__name__)


@app.route("/health")
def health():
    logger.info("health check")
    return jsonify({"status": "ok"})


@app.route("/")
def index():
    logger.info("index request")
    return jsonify({"message": "Hello from Session 9"})


@app.route("/error")
def error():
    logger.error("simulated error endpoint hit")
    return jsonify({"error": "simulated server error"}), 500


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
