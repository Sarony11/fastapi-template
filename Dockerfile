FROM python:3.10 as builder

WORKDIR /src

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install -r requirements.txt


FROM python:3.10-slim

COPY --from=builder /opt/venv /opt/venv

COPY . /app
WORKDIR /app

ENV PATH="/opt/venv/bin:$PATH"
EXPOSE 8000
ENTRYPOINT ["/opt/venv/bin/python"]
CMD ["src/api.py"]