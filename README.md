# Console manage projects
It is simple version for manage projects env

Add in your ~/.bashrc

set PATH so it includes user's private bin if it exists

```bash
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi
```

Copy this script into ~/bin and set executable bit chmod +x ~/bin/venv.sh
Add this script to your ~/.bashrc

```bash
source ~/bin/venv.sh
```