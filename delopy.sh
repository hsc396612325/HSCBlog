#/bin/sh
cd /Users/bytedance/blog
hugo
cd public
git add .
git commit -m $1
git push origin gh-pages
cd ..
git add .
git commit -m $1
git push origin master
