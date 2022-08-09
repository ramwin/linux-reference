import logging
import syncthing
from dotenv import dotenv_values, load_dotenv


logging.basicConfig(
    format="%(asctime)s, %(message)s",
    level=logging.INFO,
)
load_dotenv()
mobile = "K6GBBQR-5A32GOY-KIJG3YS-I2P53BW-ISY4DEW-FZKNJKB-5OMQ4HU-PNINNQK"
folder = "eukkp-erdmv"

client = syncthing.Syncthing(dotenv_values()["APIKEY"])
logging.info(client.db.completion("", folder))
logging.info(client.db.completion(mobile, folder))

logging.info(client.db.scan(folder, sub="/"))

logging.info(client.db.completion("", folder))
logging.info(client.db.completion(mobile, folder))
