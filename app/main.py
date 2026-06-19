import logging
import os
import watchtower

from flask import Flask, jsonify

LOG_GROUP_NAME = os.environ.get("LOG_GROUP_NAME", "/app/local")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

if LOG_GROUP_NAME != "/app/local":
    cw_handler = watchtower.CloudWatchLogHandler(
        log_group_name=LOG_GROUP_NAME,
        stream_name="app",
    )
    cw_handler.setFormatter(logging.Formatter(
        '{"time":"%(asctime)s","level":"%(levelname)s","msg":"%(message)s"}'
    ))
    logger.addHandler(cw_handler)

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
