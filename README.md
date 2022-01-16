# seekwatcher

This https://github.com/trofi/seekwatcher repository is a conversion
of http://oss.oracle.com/~mason/seekwatcher/ hg repository initially
maintained and developed by Chris Mason.

I personally don't intent to add any new features to original
`seekwatcher` by Chris Mason and would like to apply only minimal
fixes to make it work for modern dependencies.

Until you know what you are doing please consider using `iowatcher` instead:
- http://masoncoding.com/iowatcher/
- http://git.kernel.org/?p=linux/kernel/git/mason/iowatcher.git

`iowatcher` reference: https://www.spinics.net/lists/linux-btrace/msg00869.html

# Dependencies observed to work

These are not minimum requiremenets, but versions I tried in Jan 2022
which worked for me:

- arch: x86_64
- linux: 5.16
- python: 3.7, 3.8, 3.9, 3.10
- cython: 0.29.24
- numpy: 1.21.4
- matplotlib: 3.5.1

# Release procedure

Add a tag v${version} and push it to github:

```
version=0.15
git tag -s "v${version}" -m "release ${version}"
git push --tags origin
```
