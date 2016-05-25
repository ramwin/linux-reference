# docker版本的启动
    docker run --restart=always --name redis -d -p 6379:6379 redis
    docker exec -it redis-server redis-cli
