FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
ENV DJANGO_SETTINGS_MODULE=mydjanjo.settings
RUN python manage.py collectstatic --noinput
EXPOSE 8000
CMD ["gunicorn", "mydjanjo.wsgi:application", "--bind", "0.0.0.0:8000"]
