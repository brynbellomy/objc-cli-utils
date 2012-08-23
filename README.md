# // objective-c cli utils

because writing bash scripts requires less therapy than fucking with xcode.

# manifest

- <u>**auto-headerdoc-objc.js**</u>: 
  i think i fed this one data via an os x automator service so that i could just highlight everything in any text editor, activate the service, and ta-da, there were a bunch of boilerplate headerdoc/appledoc-ready comments.
- <u>**clean-global-pod-cache**</u>: 
  this is for working with cocoapods.  it wipes the global cache of downloaded pods in the event that you're doing a lot of rapid local pod development and are having to change your podspec(s) around a lot.
- <u>**clean-pods**</u>: 
  run this from inside a folder containing your `.xcodeproj` file.  it'll wipe the `Pods/` folder and `Podfile.lock`.  after this, just run `pod install` and pray.
- <u>**objc-gitignore**</u>: 
  downloads [this gist](https://gist.github.com/3288122) and appends (i.e. **non-destructively**) it to the `.gitignore` file in the current folder.

# how to install

```bash
mkdir -p ~/src
git clone git://github.com/brynbellomy/objc-cli-utils.git ~/src/objc-cli-utils
for file in ~/src/objc-cli-utils
do
	ln -s ~/src/objc-cli-utils/`basename "$file"` /usr/local/bin/`basename "$file"`
done
```

... or something like that.  god i hate bash.  but man oh man, i hate xcode ~so~ much more.

# authors

bryn austin bellomy < <bryn.bellomy@gmail.com> >

# license

MIT.  after all, xcode 4.x.x makes me feel deeply for humanity.  here's your advance warning: scripts do things.  so if you wipe out important shit, don't get in touch.


