server {
    listen 80;
    server_name wsl.ramwin.com;
    location /proxy/ {
        proxy_pass http://localhost:8000/proxy/;
        add_header 'Access-Control-Allow-Origin' '*';
    }
}
