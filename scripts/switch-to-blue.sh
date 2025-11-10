#!/bin/bash
echo "Switching traffic to BLUE environment..."

cat > nginx/nginx.conf <<'EOF'
events {
    worker_connections 1024;
}

http {
    upstream backend {
        server blue-app:3000;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /health {
            proxy_pass http://backend/health;
        }
    }
}
EOF

docker exec nginx-lb nginx -s reload

echo "Traffic switched to BLUE environment successfully!"
