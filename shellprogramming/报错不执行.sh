set -e
set -o pipefail

echo "123";
echo "456";

mkdir test && echo "OK" && mkdir test;  # 多条命令
mkdir test && mkdir test && mkdir test;  # 多条命令不会触发exit

echo "创建失败但是输出OK";

mkdir test2;

echo "创建成功";
