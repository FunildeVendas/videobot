import json
import os
import ssl

from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "attendee.settings.production")

sslCertRequirements = None
if os.getenv("DISABLE_REDIS_SSL"):
    sslCertRequirements = ssl.CERT_NONE
elif os.getenv("REDIS_SSL_REQUIREMENTS"):
    if os.getenv("REDIS_SSL_REQUIREMENTS") == "none":
        sslCertRequirements = ssl.CERT_NONE
    elif os.getenv("REDIS_SSL_REQUIREMENTS") == "optional":
        sslCertRequirements = ssl.CERT_OPTIONAL
    elif os.getenv("REDIS_SSL_REQUIREMENTS") == "required":
        sslCertRequirements = ssl.CERT_REQUIRED

if sslCertRequirements is not None:
    app = Celery(
        "attendee",
        broker_use_ssl={"ssl_cert_reqs": sslCertRequirements},
        redis_backend_use_ssl={"ssl_cert_reqs": sslCertRequirements},
    )
else:
    app = Celery("attendee")

if os.getenv("CELERY_BROKER_TRANSPORT_OPTIONS"):
    app.conf.update(
        broker_transport_options=json.loads(os.getenv("CELERY_BROKER_TRANSPORT_OPTIONS"))
    )

app.config_from_object("django.conf:settings", namespace="CELERY")

app.conf.imports = (
    "bots.tasks.run_bot_task",
    "bots.tasks.deliver_webhook_task",
)

app.autodiscover_tasks()
