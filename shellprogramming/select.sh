#!/bin/bash
# Xiang Wang @ 2016-03-27 19:51:52

PS3="Choose (1-5):"
echo "Choose from the list below."
select name in red green blue yellow magenta
do
    break
done
if [ "$name" = "" ]; then
    echo "Error in entry."
fi
echo "You chose $name."
