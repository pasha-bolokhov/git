#!/bin/sh
#
# Copyright (c) 2014 Pasha Bolokhov
#

test_description='alternative repository path specified by --git-dir is ignored by add and status'

. ./test-lib.sh

#
# Create a tree:
#
#	repo-inside/  repo-outside/
#
#
# repo-inside:
# 	a  b  c  d  dir1/ dir2/ [meta/]
#
# repo-inside/dir1:
# 	e  f  g  h  meta/  ssubdir/
#
# repo-inside/dir1/meta:
# 	aa
#
# repo-inside/dir1/ssubdir:
# 	meta/
#
# repo-inside/dir1/ssubdir/meta:
# 	aaa
#
# repo-inside/dir2:
#	meta
#
#
#
# repo-outside:
#	external/  tree/
#
# repo-outside/external:
#	[meta/]
#
# repo-outside/tree:
#	n  o  p  q  meta/  sub/
#
# repo-outside/tree/meta:
#	bb
#
# repo-outside/tree/sub:
#	meta/
#
# repo-outside/tree/sub/meta:
#	bbb
#
#
# (both of the above [meta/] denote the actual repositories)
#

#
# First set of tests (in "repo-inside/"):
# ---------------------------------------
#
# Name the repository "meta" and see whether or not "git status" includes or
# ignores directories named "meta". Directory "meta" at the top level of
# "repo-inside/"is the repository and appears upon the first "git init"
#
#
# Second set of tests (in "repo-outside/"):
# -----------------------------------------
#
# Put the work tree into "tree/" and repository into "external/meta"
# (the latter directory appears upon the corresponding "git init").
# The work tree again contains directories named "meta", but those ones are
# tested not to be ignored now
#

test_expect_success "setup" '
	mkdir repo-inside/ &&
	(
		cd repo-inside/ &&
		for f in a b c d
		do
			echo "DATA" >"$f" || exit 1
		done &&
		mkdir -p dir1/meta dir1/ssubdir/meta &&
		for f in e f g h
		do
			echo "MORE DATA" >"dir1/$f" || exit 1
		done &&
		echo "EVEN more Data" >dir1/meta/aa &&
		echo "Data and BAIT" >dir1/ssubdir/meta/aaa &&
		mkdir dir2 &&
		echo "Not a Metadata File" >dir2/meta &&
		git --git-dir=meta init
	) &&
	mkdir repo-outside/ repo-outside/external repo-outside/tree &&
	(
		cd repo-outside/tree &&
		for f in n o p q
		do
			echo "Literal Data" >"$f" || exit 1
		done &&
		mkdir -p meta sub/meta &&
		echo "Sample data" >meta/bb &&
		echo "Stream of data" >sub/meta/bbb &&
		git --git-dir=../external/meta init
	)
'


#
# The first set of tests (the repository is inside the work tree)
#
test_expect_success "'git status' ignores the repository directory" '
	(
		cd repo-inside &&
		git --git-dir=meta --work-tree=. status --porcelain --untracked=all >actual+ &&
		grep meta actual+ | sort >actual &&
		cat >expect <<-\EOF &&
		?? dir1/meta/aa
		?? dir1/ssubdir/meta/aaa
		?? dir2/meta
		EOF
		test_cmp expect actual
	)
'

test_expect_success "'git add -A' ignores the repository directory" '
	(
		cd repo-inside &&
		git --git-dir=meta --work-tree=. add -A &&
		git --git-dir=meta --work-tree=. status --porcelain >actual+ &&
		grep meta actual+ | sort >actual &&
		cat >expect <<-\EOF &&
		A  dir1/meta/aa
		A  dir1/ssubdir/meta/aaa
		A  dir2/meta
		EOF
		test_cmp expect actual
	)
'

test_expect_success "'git grep --exclude-standard' ignores the repository directory" '
	(
		cd repo-inside &&
		test_might_fail git --git-dir=meta \
			grep --no-index --exclude-standard BAIT >actual &&
		cat >expect <<-\EOF &&
		dir1/ssubdir/meta/aaa:Data and BAIT
		EOF
		test_cmp expect actual
	)
'

#
# The second set of tests (the repository is outside of the work tree)
#
test_expect_success "'git status' acknowledges directories 'meta' \
if repo is not within work tree" '
	rm -rf meta/ &&
	(
		cd repo-outside/tree &&
		git --git-dir=../external/meta init &&
		git --git-dir=../external/meta --work-tree=. status --porcelain --untracked=all >actual+ &&
		grep meta actual+ | sort >actual &&
		cat >expect <<-\EOF &&
		?? meta/bb
		?? sub/meta/bbb
		EOF
		test_cmp expect actual
	)
'

test_expect_success "'git add -A' adds 'meta' if the repo is outside the work tree" '
	(
		cd repo-outside/tree &&
		git --git-dir=../external/meta --work-tree=. add -A &&
		git --git-dir=../external/meta --work-tree=. status --porcelain --untracked=all >actual+ &&
		grep meta actual+ | sort >actual &&
		cat >expect <<-\EOF &&
		A  meta/bb
		A  sub/meta/bbb
		EOF
		test_cmp expect actual
	)
'

test_done
