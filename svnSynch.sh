# This scipt synchronizes GIT and SVN repositories
# IT SHOULD BE RUN WITH "bash -e svnSynch.sh" !!!
#
# It assumes repository was taken with 
# git-svn init http://host:port/svn/repos/pathToTrunk myRepo
# cd myRepo
# git config svn.authorsfile /path/toFile/thanMapsSvnUsersToGitUserEmails/
# git-svn fetch           or        git-svn fetch > ../out.txt 2>&1 &
# (this one takes 12-100 hours, so maybe run in background - 2nd one)
# git-svn show-ignore > .gitignore
#
# Note that you will need to patch git-svn scipt wherever you have it installed.
# It is a perls script so no worries. Find "require Term::ReadKey;"
# and comment lines with # until Term::ReadKey::ReadMode('restore');
# then set my $password = ''; or whatever value you need for given user
#
# Now this script should be run every 5 minutes or so.
# it will feth all the SVN changes and dcommit all the git changes.
# If conflicts occures script exits, the parent script should send email.
# Someone will need to resolve them manually, probably with
# git-svn fetch
# git merge -s recursive -X ours git-svn
# git-svn dcommit --username=piotrp
# or in worst case git reset --hard somehwereBeforeProblemsStarted, then git-svn rebase
#
# This SVN-synchronizing-repo need to be always on master branch.
# If it is doing merges it will block incoming pushes

# Fetch most recent SVN changes first
git-svn fetch

svnChanges=`git log --pretty="%h" master..git-svn`
gitChanges=`git log --pretty="%h" git-svn..master`

if [ -n "$svnChanges" -o -n "$gitChanges" ] ; then
  echo "`date +"%F %k:%M:%S"` Synchronization started"
  # Dont accept pushes for a while
  git config receive.denyCurrentBranch "refuse"
  # Wait for any pending pushes to finish
  sleep 30
  # Required on non bare repositories that allows pushing changes
  git reset --hard
  # Put git changes on top of SVN recent changes
  git-svn rebase || {
    echo "standard rebase failed, aborting and retrying"
    git rebase --abort
    git-svn rebase -s ours
  }
  if [ -n "$gitChanges" ] ; then
    # Commit all Git changes to SVN with single user.
    # ---> Ask Git commiters to put theit name in commit message
    git-svn dcommit --username=piotrp
  fi
  # Continue accepting pushes
  git config receive.denyCurrentBranch "ignore"
  echo "`date +"%F %k:%M:%S"` Synchronization ended"
else
  echo "`date +"%F %k:%M:%S"` Nothing to synchronize"
fi