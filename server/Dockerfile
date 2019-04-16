FROM python:3.8-alpine
WORKDIR /app
COPY api/requirements.txt /app/requirements.txt
RUN pip3 install -r requirements.txt
COPY api/*.py /app/
VOLUME ["/app/data/"]
ENTRYPOINT ["uvicorn"]
CMD ["server:app", "--host", "0.0.0.0", "--port", "8080", "--reload"]