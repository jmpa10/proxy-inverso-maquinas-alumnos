FROM python:3.11-alpine

WORKDIR /app
RUN pip install --no-cache-dir jinja2

COPY generate.py /app/
COPY templates/ /app/templates/

CMD ["python", "generate.py"]
