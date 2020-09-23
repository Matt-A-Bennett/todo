#!/bin/bash

# set path
path=$TODO_PATH

# set up dummy files 
touch tick_propagate.md untick_propagate.md ${path}/removed_tasks.md

# parse args in
while getopts 't:u:d:h' OPTION; do
    case "$OPTION" in
        t) 
            IFS=","
            tick=($OPTARG) ;;
        u) 
            IFS=","
            untick=($OPTARG) ;;
        d)
            IFS=","
            remove=($OPTARG) ;;
        h)
            echo -e "\nusage: todo [-h] [-t int [int,int ...]] [-u int [int,int ...]] [-d int [int,int ...]]\n"

            echo -e "Function description: Collects various todo list items scattered around different files and directories into a single master todo list.\n"

            echo -e "optional arguments:"
            echo -e "-h, show this help message and exit"
            echo -e "-t int [int,int ...]  which items to tick (comma,separated)"
            echo -e "-u int [int,int ...]  which items to untick (comma,separated)"
            echo -e "-d int [int,int ...]  which items to delete (comma,separated)\n"

            # clean up and exit
            rm tick_propagate.md untick_propagate.md
            exit 1 ;;
    esac
done

# gather tasks that will be (un)ticked and convert to a regex to find the items
# in the original files
for i in "${tick[@]}"; do
    sed -n "${i}"p ${path}/master_todo.md >> tick_propagate.md
    sed -i "s/- \[/- \\\[/" tick_propagate.md
done
for i in "${untick[@]}"; do
    sed -n "${i}"p ${path}/master_todo.md >> untick_propagate.md
    sed -i "s/- \[/- \\\[/" untick_propagate.md
done

# apply regex and (un)tick the box
while read dir; do
    for file in $dir/*.md; do
        while read -r line; do 
            sed -i "/${line}/ s/- \[ ]/- \[x]/" $file
        done <tick_propagate.md
        while read -r line; do 
            sed -i "/${line}/ s/- \[x]/- \[ ]/" $file
        done <untick_propagate.md
    done
done <${path}/dirs_to_search.txt

# tick/untick master tasks
for i in "${tick[@]}"; do
    sed -i "${i}s/- \[ ]/- \[x]/" ${path}/master_todo.md
done
for i in "${untick[@]}"; do
    sed -i "${i}s/- \[x]/- \[ ]/" ${path}/master_todo.md
done

# remove any tasks from master_todo.md and store in removed_tasks.md
for i in "${remove[@]}"; do
    sed -i "${i} { w tmp
    d }" ${path}/master_todo.md
    cat tmp >> ${path}/removed_tasks.md
done

# grep all the files and append to master_todo.md (unless it's on the removed list)
while read dir; do
    for file in $dir/*.md; do
        grep "(deadline:" "${file}" | while read -r task; do
            echo $task > tmp
            task_pattern=$(sed "s/- \[/- \\\[/" tmp)
            if ! grep -qe "$task_pattern" ${path}/removed_tasks.md
            then
                echo $task >> ${path}/master_todo.md
            fi
        done
    done
done <${path}/dirs_to_search.txt

# sort by task description then delete duplicate adjecent lines
sort -k3 ${path}/master_todo.md > sorted.md
uniq -s5 sorted.md filtered.md

# sort by date
cat filtered.md | sort -t: -k2 | sort -t- -k3,3 -s > ${path}/master_todo.md

# clean up
rm tick_propagate.md untick_propagate.md sorted.md filtered.md tmp 