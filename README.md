# Flash Flow


## Installation

Add this line to your application's Gemfile:

    gem 'flash_flow'

And then run:

    $ bundle install
    $ bundle exec flash_flow --install

Or install it yourself as:

    $ gem install flash_flow

And then run:

    $ flash_flow --install

After "installing" flash_flow, you'll have a file "config/flash_flow.yml.erb". If your remote is origin,
your master branch is master, and you're fine using "acceptance" as the branch that flash_flow owns, you
are ready to go for flash_flow basic. If not, edit that file and change branch and remote names accordingly.

## Usage
flash_flow is a ruby script which, in the simplest case, can just be run by calling `flash_flow`.
What that will do (once your application is properly configured) is:

1. Push your branch to the `merge_remote`
2. Reset your `merge_branch` to be the same as your `master_branch`
3. Get your list of pull requests from github (or use the saved list, more on that later)
4. Filter out any "removed" branches
5. Merge the rest into the newly created `merge_branch`
6. Force push the `merge_branch` to the `merge_remote`

### Notes

1. Step 1 will not push your branch if you're on either the `merge_branch` or `master_branch`, but it will
still merge all the other branches and push the result.
2. flash_flow uses your local git repo. It resets everything back to the branch you started in, but you should not do
anything else in your repo while it's running because lots of mayhem will ensue.


### Configuring a lock
We use the "lock" configuration in flash_flow.yml. The lock ensures that no one else is running flash_flow
while you are so that you don't inadvertently have your newly pushed branch overwritten. The way we lock you
out is super janky, we open an issue on github when flash_flow starts and close it when flash_flow is done.
To configure the lock you need to specify the class name, your github token, your github repo, and the issue_id
that you want to open and close each time. The email alerts you get from github about this issue are annoying
and should be ignored.

### Configuring branches
We use github to track our branches that we want to merge, and there are a few things about that worth noting.
In step 1 after your branch is pushed, a pull request into `master_branch` will be created on github.  If you
add the "do not merge" label to a pull request, it will be excluded from the `merge_branch`. This is extremely
useful whenever one of your co-workers breaks the build, you can either run `flash_flow --no-merge` from their
branch, or go directly to github and add the "do not merge" label and then re-run flash_flow from your branch.
To use github as your source of merge branches you have to configure it with the class name, github token and
repo, your master branch name and both the unmergeable label and do not merge label, which must exist on github.
The unmergeable label is added to a pull request that has a conflict that can't be resolved and is therefore
excluded from the merge branch.

### Configuring an issue tracker
We use Pivotal Tracker. Anytime flash_flow is run, all the branches that get merged, if they have any stories
associated with them (added via the `--stories` option), those stories will transition to "finished" if they
were previously "started". When code deploys to our review environment, our deploy script runs
`flash_flow --review-deploy`, which transitions stories associated with merged branches from "finished" to
"delivered". At the same time, for a branch that has been removed ("--no-merge"), if the story is "delivered"
it will transition back to "finished". In addition, as part of our production deploy
script, we run `flash_flow --prod-deploy`, which takes all the stories that are newly in the `master_branch`
and adds a comment "Deployed to production on 12/25/2015 at 11:11pm". So using the story option can be handy.

### Configuring hipchat
When a branch other than the one you're on doesn't merge cleanly and can't be fixed by rerere (more on that later
too), a notification can go out to Hipchat. The Hipchat notifier needs your token (api v2 token) and the room
to which the message will be sent.

### Runtime options

#### -n, --no-merge
Runs flash_flow, but excludes the branch that you're on from the merge branch. If the branch you're on has breaking
tests, you may want to get it out of your `merge_branch`, and this will do that and ensure that the next times
flash_flow is run by anyone else it will not be included. It will add the "do not merge" label to your github pull
request if you're using that. Anytime you run flash_flow without this option, the branch you're running from will
be included in the `merge_branch` even if it has previously been set to "do not merge".

#### --story <story_id>
Associates a story id with this branch. See "configuring an issue tracker" for why this can be useful.

#### --stories <story_id1,storyid2...>
Same as --story, but a comma-separated list so you can pass more than one story at a time.

#### -f, --force-push
Forces pushes your branch. All it does is add "-f" to the git push command, so you'd better make sure you know what
you're doing if you use this. The `merge_branch` always gets force pushed at the end, this option has nothing to do
with that.

#### --config-file FILE_PATH
This tells flash_flow how to find the configuration file. If you just put the file in config/flash_flow.yml you will
never need this option.

#### --prod-deploy
Passing this option makes every other option useless (except for the --config-file), because this is the only time
flash_flow doesn't do all the merging and pushing and notifying. This option just calls
"IssueTracker#production_deploy". If you have Pivotal Tracker configured it will look at all stories associated with
branches, and if that branch is deployed to `master_branch` it will add a comment to the story about it having been
deployed to production.

### Merge conflicts
When we first started using flash_flow, if your branch had a merge conflict you were out of luck. You had to wait for
the branch that you were conflicting with to be merged to master, merge master into your branch, and then try again to
get your code into the merge branch.

Then we discovered git rerere, which is the coolest feature of git that almost no one seems to have heard of. Googling
it turns up a few really good resources on how it works, but in one sentence or less what it does is remember how you
resolved conflicts and apply those patches.

If your branch has a conflict with the `merge_branch` flash_flow will look for a rerere patch and apply that if it
exists. If it doesn't, flash_flow will not merge your branch (but will continue merging all the others), and it will
spit out instructions for how to make your branch merge successfully. Once you follow those instructions (which involve
resolving the merge conflicts and saving the resolution), the next time you run flash_flow it will use that resolution
and everything will be sunshine and ponies.

In addition, flash_flow takes all your patches and copies them into the `merge_branch` where they are saved. Every time
flash_flow is run, those patches are first copied out of the `merge_branch` into your local rerere cache. The result of
this is that every time flash_flow is run all previous resolutions are available so once you've merged your branch and
flash_flow'ed it, it will merge successfully for everyone else too. rerere ftwftwftw.

## Contributing

1. Fork it ( https://github.com/flashfunders/flash_flow/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
