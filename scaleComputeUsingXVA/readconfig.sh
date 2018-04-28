readIni() {
    file=$1;section=$2;item=$3;
    val=$(awk -F '=' '/\['${section}'\]/{a=1} (a==1 && "'${item}'"==$1){a=0;print $2}' ${file})
    echo ${val}
}

writeIni() {
    file=$1;section=$2;item=$3;val=$4
    awk -F '=' '/\['${section}'\]/{a=1} (a==1 && "'${item}'"==$1){gsub($2,"'${val}'");a=0} {print $0}' ${file} 1<>${file}
}

readIniSections() {
    file=$1;
    val=$(awk '/\[/{printf("%s ",$1)}' ${file} | sed 's/\[//g' | sed 's/\]//g')
    echo ${val}
}