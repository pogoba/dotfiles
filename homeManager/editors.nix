{ pkgs, lib, config, ...}: let 
  vim-submode = pkgs.callPackage ../pkgs/vim-submode.nix { };
  my-vim-paste-easy = pkgs.vimUtils.buildVimPlugin {
    name = "vim-paste-easy";
    src = pkgs.fetchFromGitHub {
      owner = "roxma";
      repo = "vim-paste-easy";
      rev = "c28c2e4fc7b2d57efb54787bc6d67120b523d42c";
      sha256 = "sha256-DbVyfr9uH3o1GSvWv06/5HO2S5JXVYZvudPN2RemOY0=";
    };
  };
  p4-syntax-highlighter-collection = pkgs.vimUtils.buildVimPlugin {
    name = "p4-syntax-highlighter-collection";
    src = pkgs.fetchFromGitHub {
      owner = "c3m3gyanesh";
      repo = "p4-syntax-highlighter-collection";
      rev = "e6525b5ea5eb31148dcc7957cb49985de6e582c3";
      sha256 = "sha256-exZ89Q30OwpIl00SG8KhRxA8vbnRNdJhZVGNZMDYLVQ=";
    };
  };
  nvim-lspconfig = pkgs.vimUtils.buildVimPluginFrom2Nix {
    pname = "nvim-lspconfig";
    version = "git-master";
    src = pkgs.fetchFromGitHub {
      owner = "neovim";
      repo = "nvim-lspconfig";
      rev = "649137cbc53a044bffde36294ce3160cb18f32c7";
      sha256 = "sha256-DnvQ8gDqvkYcDwxQzQiIlLpiBI7xmVJ8J9VYCeWXwfc=";
    };
    meta.homepage = "https://github.com/neovim/nvim-lspconfig/";
  };

  vimplugins = with pkgs.vimPlugins; [ 
    my-vim-paste-easy
    vim-sensible 
    # detenctindent
    nerdcommenter
    molokai
    nerdtree
    rainbow_parentheses-vim
    fzf-vim
    gitgutter
    vim-airline
    vim-airline-themes
    indentLine
    zoomwintab-vim # <C-w>o to zoom a buffer to whole screen size
    vim-tmux-navigator
    vim-bufkill
    ack-vim
    #vim-osc52
    vim-oscyank
    tabular
    vim-LanguageTool
    vim-obsession # start recording vim sessions for a directory with :Obsess and restore it with vim -S
    vim-submode
    vim-cpp-enhanced-highlight
    p4-syntax-highlighter-collection
  ];
#    tpope/vim-sensible
#    roryokane/detectindent
#    ddollar/nerdcommenter
#    dense-analysis/ale
#    tomasr/molokai
#    scrooloose/nerdtree
#    junegunn/rainbow_parentheses.vim
#    junegunn/fzf
#    ctrlpvim/ctrlp.vim # vimscript only fuzzy search
#    airblade/vim-gitgutter
#    vim-airline/vim-airline
#    vim-airline/vim-airline-themes
#
#    Yggdroot/indentLine # mark levels of line indentation |
#    troydm/zoomwintab.vim
#    christoomey/vim-tmux-navigator
#    qpkorr/vim-bufkill # :BD is :bdelete without closing windows
#  ];
in {
  config.home.packages = with pkgs; [
    (
      vim-full.customize {
        name = "vim";
        vimrcConfig.customRC = builtins.readFile ./vimrc + ''
        '';
        vimrcConfig.packages.nixbundle.start = with pkgs.vimPlugins; vimplugins ++ [
          ale
        ];
      }
    )
    # (
    #   neovim.override (let
    #     use-ale = true;
    #   in {
    #     #vimAlias = true;
    #     configure = {
    #       customRC = builtins.readFile ./vimrc + lib.optionalString (!use-ale) ''
    #         " activate nvim builtin lsc
    #         lua << EOF
    #            require('lspconfig').bashls.setup{}
    #            -- require('lspconfig').ccls.setup{}
    #            require('lspconfig').pyright.setup{}
    #            require('lspconfig').clangd.setup{}
    #            require('lspconfig').ruff_lsp.setup{}
    #            require('lspconfig').rust_analyzer.setup{}

    #            -- Mappings.
    #            -- See `:help vim.lsp.*` for documentation on any of the below functions
    #            local bufopts = { noremap=true, silent=true, buffer=bufnr }

    #            -- UI
    #            vim.diagnostic.config({
    #              virtual_text = false -- dont clutter everything with error descriptions
    #            })
    #         EOF
    #         command ALEHoverThisisnotaleanymoredumbass lua vim.lsp.buf.hover()
    #         command ALEGoToImplementationThisisnotaleanymoredumbass lua vim.lsp.buf.implementation()
    #         command ALEGoToDefinitionThisisnotaleanymoredumbass lua vim.lsp.buf.definition()
    #         command ALEFindReferencesThisisnotaleanymoredumbass lua vim.lsp.buf.references()
    #         command ALERenameThisisnotaleanymoredumbass lua vim.lsp.buf.rename()
    #         " vim.lsp.buf.signature_help
    #         " vim.lsp.buf.declaration
    #         " vim.lsp.buf.type_definition
    #         " vim.lsp.buf.code_action

    #         " set completeopt=menu,preview
    #         " no helpdoc window (preview)
    #         set completeopt=menu

    #         " cancel autocomplete with C-c
    #         inoremap <C-c> <C-e>

    #         " " configure nvim autocompletion with deoplete
    #         " call deoplete#custom#option('auto_complete_popup', 'manual')
    #         " inoremap <expr><C-n>     deoplete#complete()
    #         " inoremap <expr><C-g>     deoplete#undo_completion()

    #         " " configure nvim autocompletion with cmp
    #         " lua << EOF
    #         "    local cmp = require('cmp')
    #         "    cmp.setup({
    #         "      mapping = cmp.mapping.preset.insert({
    #         "        ['<C-c>'] = cmp.mapping.abort(),
    #         "        ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
    #         "      }),
    #         "    })
    #         " EOF
    #         ''
    #         +
    #         ''

    #         " let bufferline manage tabline
    #         let g:airline#extensions#tabline#enabled = 0
    #         let g:airline_theme='base16_material_darker'
    #         map <C-i> :BufferLineCyclePrev<CR>
    #         map <C-o> :BufferLineCycleNext<CR>
    #         map <C-p> :BufferLineMovePrev<CR>
    #         map <C-[> :BufferLineMoveNext<CR>

    #         set termguicolors
    #         lua << EOF
    #         require("bufferline").setup{}
    #         require'nvim-treesitter.configs'.setup {
    #           -- A list of parser names, or "all" (the four listed parsers should always be installed)
    #           -- ensure_installed = { "c", "lua", "vim", "help" },
    #
    #           -- Install parsers synchronously (only applied to `ensure_installed`)
    #           sync_install = false,
    #
    #           -- Automatically install missing parsers when entering buffer
    #           -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
    #           auto_install = false,
    #
    #           -- List of parsers to ignore installing (for "all")
    #           ignore_install = { "javascript" },
    #
    #           ---- If you need to change the installation directory of the parsers (see -> Advanced Setup)
    #           -- parser_install_dir = "/some/path/to/store/parsers", -- Remember to run vim.opt.runtimepath:append("/some/path/to/store/parsers")!
    #           parser_install_dir = "/tmp",
    #
    #           highlight = {
    #             enable = true,
    #
    #             -- NOTE: these are the names of the parsers and not the filetype. (for example if you want to
    #             -- disable highlighting for the `tex` filetype, you need to include `latex` in this list as this is
    #             -- the name of the parser)
    #             -- list of language that will be disabled
    #             -- disable = { "c", "rust" },
    #             -- Or use a function for more flexibility, e.g. to disable slow treesitter highlight for large files
    #             disable = function(lang, buf)
    #                 local max_filesize = 100 * 1024 -- 100 KB
    #                 local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
    #                 if ok and stats and stats.size > max_filesize then
    #                     return true
    #                 end
    #             end,
    #
    #             -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
    #             -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
    #             -- Using this option may slow down your editor, and you may see some duplicate highlights.
    #             -- Instead of true it can also be a list of languages
    #             additional_vim_regex_highlighting = false,
    #           },
    #         }
    #         EOF
    #       '';
    #       packages.myPlugins = with pkgs.vimPlugins; {
    #         start = vimplugins ++ [
    #           vim-lastplace
    #           vim-nix
    #           bufferline-nvim
    #           nvim-treesitter
    #           nvim-treesitter.withAllGrammars
    #           telescope-nvim
    #           #deoplete-nvim
    #           #nvim-cmp # provides shortcuts for us
    #         ] ++
    #         (lib.optional (!use-ale) nvim-lspconfig) ++
    #         (lib.optional use-ale ale);
    #         opt = [];
    #       };
    #     };
    #   })
    # )
  ];
}
