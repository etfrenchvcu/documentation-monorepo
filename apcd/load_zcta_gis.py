"""Downloads a ZCTA-level shape file from the census bureau to a local directory."""
import io
from os import path
import zipfile

import requests

GIS_PATH = '../data/tl_2019_us_zcta510'
URL = 'https://www2.census.gov/geo/tiger/TIGER2019/ZCTA5/tl_2019_us_zcta510.zip'

if not path.exists(GIS_PATH):
    request = requests.get(URL, stream=True)
    zipf = zipfile.ZipFile(io.BytesIO(request.content))
    zipf.extractall(GIS_PATH)