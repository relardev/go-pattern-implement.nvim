# GO Component Generator NeoVim harness

## prequisites

 1. `go-command-generator` available in path

## use with lazy

```
{
    "relardev/go-component-generator.nvim",

    config = function()
        require('go-component-generator').setup()
    end,
    dependencies = {
        { 'nvim-lua/plenary.nvim' },
    }
}

```
