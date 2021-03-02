directory="/D/王祥/相册";
folders=(`ls -1 ${directory} | grep '^20'`)
# echo ${folders}
for i in ${folders[*]}; do
    dir=${directory}/$i
    echo "mv ${dir}"
    mv ${dir} ./
    git add $i
    git commit -m $i
    git push origin master
done
