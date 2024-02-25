# GO Component Generator NeoVim harness

## prequisites

 1. `go-component-generator` available in path

## install with lazy

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

## usage

select `interface type` in visual selection and call `:GoImplement`
