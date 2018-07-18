#!/bin/bash

#===================================================================#
#   System Required:  windows with git-bash                         #
#   Description: Create git Release Note to MarkDown file           #
#   Author: QingLi <Chris.Lyle101@gmail.com>                        #
#   Usage : double click                                            #
#   Intro : http://gerrit                                           #
#===================================================================#

AllTag=true;
MaxTag=20;

source /etc/profile

# function pause()
# @brief: 暂停函数
function pause(){
    #T=`echo "$*" | iconv -f gbk -t UTF-8`
    read -n 1 -p "$*" INP
    if [ "$INP" != '' ] ; then
            echo -ne '\b \n'
    fi
}

# 查找git仓库根目录
find_git_ROOT() {
    dir="$1"
    until [ "$dir" -ef / ]; do
    if [ -f "$dir/.git/HEAD" ]; then
        echo `cd "$dir" && pwd`
        return 0
    fi
        dir="$dir/.."
    done
    echo "Not_a_git_Repo"
    return 1
}

# function git_log()
# @brief: 解析两个标签之间的git log到$GitLogFile
# @Para:  $1: TagA ;  $2: TagB
function git_log(){
    git log --pretty=format:"F@G"%h"F@G"%an"F@G"%cd"F@G"%B"New@LineF@G" --date=format:%c $1...$2 \
    | sed ':label;N;s/\n/<br>/;b label' | sed -e 's/New@LineF@G<br>/F@G\n/g' -e 's/New@LineF@G/F@G/g' \
    | sed -e 's/<br><br>Change-Id:.*F@G/F@G/g' -e 's/  /　/g' -e 's/<br><br>/<br>/g' \
    | sed 's/|/│/g' | sed 's/F@G/|/g' >> "$GitLogFile"
}

# function tag_message()
# @brief: 解析给定tag标签的信息到 $GitLogFile
# @Para:  $1: Tag Name
function tag_message(){
    echo -e "> **Date**: \c" >> "$GitLogFile"
    git show -s --format=%ad --date=format:"%Y/%m/%d/ %H:%M" $1^{commit} >> "$GitLogFile"
    if [[ `git cat-file -t $1` =~ tag ]]; then
        echo "> **Tag Messages** :" >> "$GitLogFile"
        git tag -n10000 -l $1 | sed "s/$1\ */> /" |sed -e 's/^\ \{4\}/> /'  -e 's/$/  /' >> "$GitLogFile"
    fi
    echo >> "$GitLogFile"
}

# function _branch_tag()
# @brief: 获取当前提交点所在分支上的所有git Tag标签
function _branch_tag(){
    git log --format='%d' | sed -e '/^$/d' -e 's/(//' -e 's/)//' | grep tag | sed 's/, /: /g' | awk -F ":" '
    {
        for (f=1; f <= NF; f+=1)
        {
            if( ($f == " tag") && ($flag != false) )
                printf("%s",$(f+1));
        }
        printf("\n");
    } '| sed -e 's/^\s//' -e 's/\s/|/g'
}

# get the Branch name
get_current_branch() {

    Current_Branch=` cd "${Prj_Home}" && git log --pretty=format:%D -1 | sed -e 's/origin\/tags\///' -e 's/\s\s/\s/g'\
    | awk 'BEGIN{FS = ","} {
        for (f=1; f <= NF; f+=1){
            if ($f ~ /origin\//){
                print $f;
                break
            }
        }
    }'|cut -c 9- `

    [[ -z $Current_Branch ]] || echo "GIT_Branch: origin/"$Current_Branch

    [[ -z $Current_Branch ]] && {
        Current_Branch=`cd "${Prj_Home}" && git log --pretty=format:%D -1 \
        | awk 'BEGIN{FS = ","} {
            for (f=1; f <= NF; f+=1){
                if ($f ~ /HEAD/) {
                    print $f;
                    break
                }
            }
        }'|cut -c 9-`
        [ -z $Current_Branch ] || echo "GIT_Branch: HEAD -> "$Current_Branch
    }

    [[ ! -z $GERRIT_BRANCH ]] && {
        Current_Branch=$GERRIT_BRANCH
        echo "GIT_Branch: Gerrit -> "$Current_Branch
    }

    [[ -z $Current_Branch ]] && {
        Current_Branch=`cd "${Prj_Home}" && git branch \
        | sed '/HEAD detached/d' | grep \* | sed 's/\*\s//'`
        [[ ! -z $Current_Branch ]] && echo "GIT_Branch: Local -> "$Current_Branch
    }

    [[ -z $Current_Branch ]] && {
        result=`cd "${Prj_Home}" && git branch -r --contains HEAD | sed '/origin\/tags\//d'`
        Current_Branch=` echo "$result" \
        | awk 'NR==1{
            for (f=1; f <= NF; f+=1){
                if ($f ~ /origin\//){
                    print $f;
                    break
                }
            }
        }'|cut -c 8- `
        line=`echo "$result" | wc -l`
        if [[ $line -gt 1 ]]; then
            echo "there are more than one branch contains on HEAD:"
            echo "$result"
            echo "Using the first one :"
        fi
        [[ ! -z $Current_Branch ]] && echo "GIT_Branch: Branch -> "$Current_Branch
    }

}



# 【项目文件(夹)检测】

# Build Directory  #Build=`pwd`
[ -z "$Build" ] && Build="$( cd "$( dirname "$0"  )" && pwd  )"
# echo
# echo "Build = "${Build}

# Project Home Directory
Prj_Home=`find_git_ROOT "$Build"`

if [[ "$Prj_Home" =~ "Not_a_git_Repo" ]]; then
    echo
    echo "Error: 请将本脚本放在GIT仓库目录下运行!"
    pause 'Press any Key Exit...'
    exit 1
fi

echo "Prj_Home = "${Prj_Home}

PRJ_Name=`echo "$Prj_Home" | awk -F '/' '{print $NF}'`

# Set log File Dir
GitLogFile="${Build}/${PRJ_Name}_Release_Note.md"

[[ -z $Current_Branch ]] && get_current_branch

PreTag=HEAD
tagB=HEAD

echo -e "\n# <center>Software Release Note</center>\n\n***" >> "$GitLogFile"


echo -e "\n- Git Branch : $Current_Branch\n\n- Tag List :\n\n[TOC]" >> "$GitLogFile"

cd "$Prj_Home"

i=0;
for gitTag in `_branch_tag `
do
    echo Generating ${gitTag%%|*} messages...
    if [ $i -lt $MaxTag ] || [ $AllTag = true ] ; then
        tagA=$PreTag
        tagB=$gitTag
        PreTag=$gitTag
        if [ $tagA == HEAD ]; then
            Result=`git log --pretty=format:"%B" $tagA...${tagB%%|*}`
            if [ ! x"$Result" == x"" ]; then
                echo -e "\n\n## Latest Commit:\n" >> "$GitLogFile"
            else
                continue
            fi
        else
            echo -e "\n\n\n## $tagA\n" >> "$GitLogFile"
            tag_message ${tagA%%|*}
        fi
        let i+=1
        echo -e "---\n" >> "$GitLogFile"
        echo "|ID|Author|Date|Commit Messages|" >> "$GitLogFile"
        echo "|:----:|:----:|:----:|-------|" >> "$GitLogFile"

        git_log ${tagA%%|*} ${tagB%%|*}
    else
        echo -e "\n --------------- Tag_Count $i > $MaxTag, break ---------------"
        break
    fi
done

# echo AllTag=$AllTag

cd "$Prj_Home"

if [ $AllTag == true ]; then
    echo -e "\nTotal Tag_Number on Branch $Current_Branch : ${i}"
    echo -e "\n\n\n## $tagB\n" >> "$GitLogFile"
    tag_message ${tagB%%|*}
    echo -e "---\n" >> "$GitLogFile"
    echo "|ID|Author|Date|Commit Messages|" >> "$GitLogFile"
    echo "|:----:|:----:|:----:|-------|" >> "$GitLogFile"

    git log --pretty=format:"F@G"%h"F@G"%an"F@G"%cd"F@G"%B"New@LineF@G" --date=format:%c ${tagB%%|*} \
    | sed ':label;N;s/\n/<br>/;b label' | sed -e 's/New@LineF@G<br>/F@G\n/g' -e 's/New@LineF@G/F@G/g' \
    | sed -e 's/<br><br>Change-Id:.*F@G/F@G/g' -e 's/  /　　/g' -e 's/<br><br>/<br>/g' \
    | sed 's/|/│/g' | sed 's/F@G/|/g' >> "$GitLogFile"
fi

# 打开生成的ReleaseNote文件:

if [ -z $Server ] || ( [ ! -z $Server ] && [ $Server != Jenkins ] ); then
    [ -z $BATCH ] && pause 'Press any Key to Open the Release Note File'
    Markdown_File=`cygpath -w "$GitLogFile"`
    start "$Markdown_File" | iconv -f gbk -t UTF-8 &
fi
