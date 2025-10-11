Snippets to enhance neovim builtin undotree (https://github.com/neovim/neovim/pull/35627).

* Diff window.
* Switch on buffer change.

```sh
nvim --cmd "set rtp^=. rtp+=./after undofile" README.md +'lua require"undotree-plus".open()' +'set winblend=20'
```

## credit
https://github.com/XXiaoA/atone.nvim
