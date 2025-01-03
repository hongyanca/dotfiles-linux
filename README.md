## My Linux Dotfiles Repo 🌟

Welcome to my dotfiles repository! 🎉 This is where I store and manage the configuration files that power my development environment and system setup. By leveraging [**GNU Stow**](https://www.gnu.org/software/stow/), I ensure all my dotfiles are cleanly symlinked, making it easy to organize, version control, and deploy them across multiple machines.



### What's Inside? 🗂️

This repo contains configuration files for tools and applications I use daily, such as:

- **Shells**: `zsh`, `fish`
- **Editors**: `neovim`
- **Terminal Tools**: `tmux`
- **Version Control Tools**: `git`
- **File Manager**: `yazi` (a fast, modern terminal file manager)
- **Utility Shell Scripts**: Handy scripts for everyday tasks (e.g., backups, cleanup, automation)
- And more!



### Why GNU Stow? 📦

GNU Stow is a powerful symlink manager that simplifies the process of linking dotfiles to their appropriate locations. Instead of manually placing files, Stow uses a directory structure to manage symlinks, ensuring that everything is neat and organized. It makes adding, updating, or removing configurations a breeze.



### How It Works:

1. Each set of configuration files lives in its own directory (e.g., `neovim/`, `zsh/`, `fish`).
2. Running `stow <directory>` creates symlinks in your `$HOME` directory (or any target location).
3. To remove a set of configurations, simply `stow -D <directory>`.



### Quick Start 🚀

1. **Clone the Repository**:

   For **generic** Linux setup, clone the main branch.

   ```bash
   rm -rf ~/.dotfiles
   git clone --depth=1 --single-branch --branch main https://github.com/hongyanca/dotfiles-linux.git ~/.dotfiles
   ```

   For the **host with designated branch**, replace BRANCH_FOR_THE_HOST for the host. It is recommended to set `BRANCH_FOR_THE_HOST` to match the hostname of the system.

   ```bash
   rm -rf ~/.dotfiles
   git clone --depth=1 --single-branch --branch BRANCH_FOR_THE_HOST https://github.com/hongyanca/dotfiles-linux.git ~/.dotfiles
   ```

   For development, clone all branches:

   ```bash
   rm -rf ~/.dotfiles
   git clone git@github.com:hongyanca/dotfiles-linux.git ~/.dotfiles
   ```

   To set a default remote Git branch to the designated branch for the host:

   ```bash
   git branch --set-upstream-to=origin/BRANCH_FOR_THE_HOST
   ```

2. **Install GNU Stow** (if not already installed):

   ```bash
   # RHEL
   sudo dnf install -y stow
   
   # Debian/Ubuntu
   sudo apt install -y stow
   
   # Arch Linux
   sudo pacman -S --needed stow
   ```

3. **Symlink a Configuration**:
   
   - **Git**
     ```bash
     rm -f ~/.gitignore_global
     rm -f ~/.gitconfig
     cd ~/.dotfiles
     stow git
     
     # Replace Git's `user.name` and `user.email` with your own.
     git config --global user.name "John Doe"
     git config --global user.email johndoe@example.com
     ```
   
   - **Tmux**
   
     ```bash
     rm -f ~/.tmux.conf
     cd ~/.dotfiles
     stow tmux
     ```
   
   - **zsh**

     ```bash
     rm -rf ~/.p10k ~/.p10k.zsh ~/.zshrc
     git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.p10k
     
     cd ~/.dotfiles
     stow zsh
     
     # Change default shell to zsh
     chsh -s $(which zsh)
     # Or
     sudo chsh -s $(which zsh) $USER
     ```
   
   - **fish**
   
     ```bash
     mkdir -p ~/.config
     rm -rf ~/.config/fish
     
     cd ~/.dotfiles
     stow fish
     
     # Change default shell to fish
     chsh -s $(which fish)
     # Or
     sudo chsh -s $(which fish) $USER
     ```
   
   - **yazi**
   
     ```bash
     mkdir -p ~/.config
     rm -rf ~/.config/yazi
     
     cd ~/.dotfiles
     stow yazi
     ```
   
   - **scripts**
   
     ```bash
     mkdir -p ~/scripts
     
     cd ~/.dotfiles
     stow scripts
     ```

4. **Undo a Configuration**:

   ```bash
   cd ~/.dotfiles
   stow -D [zsh|fish|yazi|...]
   ```

5. **Customize Your Setup**: Edit files to your heart's content and push changes back to this repo to version control your tweaks.



### Structure 📁

```
.dotfiles/
├── README.md              # You're here!
├── git/                   # Git configurations
├── tmux/                  # Tmux configurations
├── zsh/                   # Zsh configurations
├── fish/                  # Fish configurations
├── yazi/                  # Yazi terminal file manager configurations
└── scripts/               # Handy utility shell scripts
```



### Contributions 💡

Feel free to fork this repo, make improvements, or suggest new tools to include! Dotfiles are personal, but there's always room for collaboration and learning.

Keep your setup portable and beautiful! Happy dotfiles hacking! 🛠️✨
