import os
import sys
import json
import time
import uuid
import datetime
import traceback

import uvicorn
import fastapi
from fastapi import Request, Depends, HTTPException, Security
from starlette.status import (
    HTTP_403_FORBIDDEN,
    HTTP_404_NOT_FOUND,
    HTTP_500_INTERNAL_SERVER_ERROR,
)
from fastapi.responses import JSONResponse
from fastapi.security.api_key import APIKeyQuery, APIKeyCookie, APIKeyHeader, APIKey
from fastapi.middleware.cors import CORSMiddleware


__version_info__ = (0, 1, 0)
__version__ = ".".join(str(v) for v in __version_info__)

API_KEY = "APIKEY"
API_KEY_NAME = "access_token"
COOKIE_DOMAIN = "*"


def now():
    return datetime.datetime.utcnow()


def log(msg):
    print(f"[{now().isoformat()}] {msg}")


def get_exception_details(num=-1):
    exc_type, exc_value, exc_traceback = sys.exc_info()
    exception_string = "".join(traceback.format_exception_only(exc_type, exc_value))
    (filename, line_number, function_name, text) = traceback.extract_tb(exc_traceback)[
        num
    ]

    error = {
        "type": str(exc_type.__name__),
        "value": str(exc_value),
        "message": exception_string,
        "location": {
            "filename": filename,
            "lineno": line_number,
            "function_name": function_name,
            "line": text,
        },
    }
    return error


app = fastapi.FastAPI()

api_v1 = fastapi.FastAPI(
    title="Template API",
    description="Template API",
    version=__version__,
)

api_v1.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

api_key_header = APIKeyHeader(name="access_token", auto_error=False)


async def get_api_key(
    api_key_header: str = Security(api_key_header),
):
    if api_key_header == API_KEY:
        return api_key_header
    else:
        raise HTTPException(
            status_code=HTTP_403_FORBIDDEN, detail="Could not validate credentials"
        )


@app.on_event("startup")
def startup_event():
    log(dict(body="Template API Service Started", context="startup_event"))


@app.middleware("http")
async def add_context(request: fastapi.Request, call_next):
    start_time = time.time()
    request_id = str(uuid.uuid4())
    if not request.query_params.get("request_id"):
        request.state.request_id = request_id
    else:
        request.state.request_id = request.query_params["request_id"]

    response = await call_next(request)
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = f"{process_time:0.6f}"
    response.headers["request_id"] = request.state.request_id
    response.headers["api_version"] = __version__
    return response


@app.get("/", include_in_schema=False)
def index():
    return JSONResponse(
        {"message": "ok", "timestamp": str(now()), "version": __version__}
    )


# async def environment(api_key: APIKey = Depends(get_api_key)):
@api_v1.get("/env", include_in_schema=True)
async def environment():
    return os.environ


@api_v1.get("/ping", summary="Ping")
async def ping(request: Request):
    log(f"Ping endpoint requested by {request.state.request_id}")
    message = {
        "id": str(uuid.uuid4()),
        "timestamp": str(datetime.datetime.utcnow()),
        "body": "Ping endpoint requested.",
        "metadata": {
            "request_id": str(request.state.request_id),
            "client_host": str(request.client.host),
            "request_headers": str(request.headers.raw),
        },
    }
    log(json.dumps(message, indent=4))
    return {"ping": "pong"}


@api_v1.post("/predict/")
def predict(observation: int, request: fastapi.Request):
    resp = None
    obs = str(observation)
    try:
        log(
            f"** Prediction request for {request.state.request_id}...\n* Received payload:\n{obs}\n* Processing..."
        )
        start = time.perf_counter()
        resp = obs * 3
        log(
            f"Response received -> {resp}. Time taken: {time.perf_counter() - start:.6f}"
        )
    except Exception as e:
        error = get_exception_details()
        log(error)
    finally:
        pass

    if resp:
        return resp
    else:
        return JSONResponse(
            status_code=500,
            content={
                "ERROR": {
                    "error": "Endpoint Failed",
                    "detail": {"Error": error["message"].strip()},
                }
            },
        )


app.mount("/api/v1", api_v1)


if __name__ == "__main__":
    try:
        uvicorn.run("api:app", host="0.0.0.0", port=int(os.getenv("API_PORT", 8000)))
    except Exception as e:
        error = json.dumps(get_exception_details(), indent=4)
        log(f"Error:\n{error}")
