let s:pipeline = []
let s:func_index = 0
let s:funcs = {}

function! wildsearch#pipeline#null(...)
  return v:null
endfunction

function! wildsearch#pipeline#fail(...)
  return v:false
endfunction

function! wildsearch#pipeline#reset_funcs()
  let s:func_index = 0
  let s:funcs = {}
endfunction

function! wildsearch#pipeline#register_func(f)
  let s:func_index += 1
  let s:funcs[s:func_index] = type(a:f) == v:t_string ? function(a:f) : a:f
  return s:func_index
endfunction

function! wildsearch#pipeline#register_funcs(fs)
  return map(copy(a:fs), {idx, f -> wildsearch#pipeline#register_func(f)})
endfunction

function! wildsearch#pipeline#unregister_func(key)
  unlet s:funcs[a:key]
endfunction

function! wildsearch#pipeline#call(key, ctx, x)
  if type(a:key) == v:t_string
    return function(a:key)(a:ctx, a:x)
  else
     return s:funcs[a:key](a:ctx, a:x)
  endif
endfunction

function! wildsearch#pipeline#set(pipeline)
  call wildsearch#pipeline#reset_funcs()

  let s:pipeline = wildsearch#pipeline#register_funcs(a:pipeline)
endfunction

function! wildsearch#pipeline#start(ctx, x)
  if len(s:pipeline) == 0
    call wildsearch#pipeline#set(wildsearch#pipeline#default())
  endif

  if !get(s:, 'wildsearch_init', 0)
    let s:wildsearch_init = 1
    call _wildsearch_init()
  endif

  let l:ctx = copy(a:ctx)
  let l:ctx.fs = s:pipeline
  let l:ctx.input = a:x
  let l:ctx.step = 0
  let l:ctx.start_time = reltime()
  " let l:ctx = {
        " \ 'fs': s:pipeline,
        " \ 'input': a:x,
        " \ 'on_finish': 'wildsearch#pipeline#on_finish',
        " \ 'on_error': 'wildsearch#pipeline#on_error',
        " \ 'start_time': reltime(),
        " \}

  call wildsearch#pipeline#do(l:ctx, a:x)
endfunction

function! wildsearch#pipeline#do(ctx, x)
  let l:ctx = copy(a:ctx)

  if a:x is v:null
    " skip
    return
  elseif a:x is v:false
    call wildsearch#pipeline#call(l:ctx.on_finish, l:ctx, a:x)
    return
  endif

  if len(l:ctx.fs) == 0
    call wildsearch#pipeline#call(l:ctx.on_finish, l:ctx, a:x)
    return
  endif

  let l:f = l:ctx.fs[0]
  let l:ctx.fs = l:ctx.fs[1:]
  let l:ctx.step += 1

  let l:res = wildsearch#pipeline#call(l:f, l:ctx, a:x)
  call wildsearch#pipeline#do(l:ctx, l:res)
endfunction

function! wildsearch#pipeline#do_error(ctx, x)
    call wildsearch#pipeline#call(a:ctx.on_error, a:ctx, a:x)
endfunction

function! wildsearch#pipeline#funcs()
  return copy(s:funcs)
endfunction

let g:opts = {'engine': 're', 'max_candidates': 500, 'fuzzy': 0}
function! wildsearch#pipeline#default()
  return [
        \ wildsearch#check({_, x -> !empty(x)}),
        \ wildsearch#python_substring(),
        \ wildsearch#python_search(g:opts),
        \ wildsearch#python_sort(g:opts),
        \ ]

  " return [wildsearch#vim_search(g:opts), wildsearch#python_uniq()]

  " return [wildsearch#sleep(3), {_, x -> x . 'a'}, {_, x -> x . 'b' }, {_, x -> x . 'c'}, {_, x -> [x]}]

  " return [wildsearch#branch(), {_, x -> [x]}]

  " return [{_, __ -> v:false}, {_, x -> [x]}]

  " return [
      " \ {_, x -> str2nr(x)},
      " \ wildsearch#branch(
      " \  [{_, x -> x + 1}, {_, x -> x + 1}],
      " \ ),
      " \ {_, x -> x + 1},
      " \ {_, x -> x + 1},
      " \ {_, x -> [string(x)]},
      " \ ]

  " return [
      " \ wildsearch#branch(
      " \  [{_, __ -> v:false}],
      " \  [{_, __ -> v:false}],
      " \  [{_, x -> x + 1}, {_, x -> x * 2}, {_, x -> x + 1}]
      " \ ),
      " \ wildsearch#sleep(0),
      " \ {_, x -> x + 1},
      " \]

  " return [
      " \ {_, x -> str2nr(x)},
      " \ wildsearch#branch(
      " \   [wildsearch#branch(
      " \     [wildsearch#sleep(1), {_, __ -> v:false}],
      " \     [wildsearch#sleep(1), {_, x -> x + 1}, {_, __ -> v:false}],
      " \   )],
      " \   [wildsearch#sleep(2), {_, x -> x + 1}],
      " \ ),
      " \ {_, x -> x * 2},
      " \ wildsearch#sleep(0),
      " \ {_, x -> x + 2},
      " \ {_, x -> [string(x)]},
      " \]
endfunction
