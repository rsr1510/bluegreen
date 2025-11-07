Write-Host "Switching traffic to GREEN environment..." -ForegroundColor Cyan

$nginxConfig = @"
events {
    worker_connections 1024;
}

http {
    upstream backend {
        server green-app:3000;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://backend;
            proxy_set_header Host `$host;
            proxy_set_header X-Real-IP `$remote_addr;
            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        }

        location /health {
            proxy_pass http://backend/health;
        }
    }
}
"@

$nginxConfig | Out-File -FilePath "nginx\nginx.conf" -Encoding UTF8 -NoNewline

docker exec nginx-lb nginx -s reload

Write-Host "Traffic switched to GREEN environment successfully!" -ForegroundColor Green