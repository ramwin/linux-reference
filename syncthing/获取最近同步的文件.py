#!/usr/bin/env python3

import logging
import requests
from dotenv import dotenv_values, load_dotenv


load_dotenv()

APIKEY = dotenv_values()["APIKEY"]
logging.basicConfig(
    format="%(asctime)s, %(message)s",
    level=logging.INFO,
)


def get_status(device_id=""):
    logging.info(f"获取{device_id or '本机'}状态")
    res_remote = requests.get(
        "http://ramwin.com:8384/rest/db/completion",
        params={
            "folter": "eukkp-erdmv",
            "device": device_id,
        },
        headers={
            "X-API-Key": APIKEY,
            "Content-Type": "application/json",
        }
    )
    try:
        res = res_remote.json()
    except Exception as e:
        logging.error(res_remote.text)
    logging.info(f"    完成度: {res['completion']}")
    logging.info(f"    字节数: {res['globalBytes']}")
    logging.info(f"    : {res}")
    return res


def scan():
    logging.info("""重新扫描""")
    requests.post(
        "http://ramwin.com:8384/rest/db/scan",
        params={
            "folter": "eukkp-erdmv",
            "sub": "/",
        },
        headers={
            "X-API-Key": APIKEY,
            "Content-Type": "application/json",
        }
    )


get_status("K6GBBQR-5A32GOY-KIJG3YS-I2P53BW-ISY4DEW-FZKNJKB-5OMQ4HU-PNINNQK")
get_status()
scan()
get_status()
get_status("K6GBBQR-5A32GOY-KIJG3YS-I2P53BW-ISY4DEW-FZKNJKB-5OMQ4HU-PNINNQK")
