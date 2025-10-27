FROM python:3.11-slim
WORKDIR /app
COPY services/payments/requirements.txt /app/requirements.txt
RUN pip install -r /app/requirements.txt
COPY services/payments/app.py /app/app.py
ENV PORT=3005
EXPOSE 3005
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "3005"]
