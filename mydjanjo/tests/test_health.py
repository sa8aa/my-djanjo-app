from django.test import TestCase, Client


class HealthCheckTest(TestCase):
    def test_health_endpoint(self):
        c = Client()
        response = c.get("/health/")
        self.assertEqual(response.status_code, 200)
