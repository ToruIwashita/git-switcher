" File: plugin/git_switcher.vim
" Author: Toru Hoyano <toru.iwashita@gmail.com>
" License: MIT License

if exists('g:loaded_git_switcher')
  finish
endif
let g:loaded_git_switcher = 1

let s:cpo_save = &cpo
set cpo&vim

if !exists('g:gsw_sessions_dir')
  let g:gsw_sessions_dir = $HOME.'/.cache/vim/git_switcher'
endif

if !exists('g:gsw_non_project_sessions_dir')
  let g:gsw_non_project_sessions_dir = 'non_project'
endif

if !exists('g:gsw_non_project_default_session_name')
  let g:gsw_non_project_default_session_name = 'default'
endif

if !exists('g:gsw_autoload_session')
  let g:gsw_autoload_session = 'no'
endif

if !exists('g:gsw_autodelete_sessions_if_branch_does_not_exist')
  let g:gsw_autodelete_sessions_if_branch_does_not_exist = 'no'
endif

augroup git_switcher
  autocmd!
  autocmd VimEnter * nested if @% == '' | call git_switcher#autocmd_for_vim_enter() | endif 
  autocmd VimLeave * call git_switcher#autocmd_for_vim_leave()
augroup END

command! GswSessionList call git_switcher#session_list()
command! GswBranch call git_switcher#branch()
command! GswBranchRemote call git_switcher#remote_tracking_branch()
command! GswFetch call git_switcher#fetch_project()
command! GswPull call git_switcher#pull_current_branch()
command! GswClearState call git_switcher#clear_stete()
command! -bang GswDeleteSessionsIfBranchDoesNotExist call git_switcher#delete_sessions_if_branch_does_not_exist(<bang>0) 
command! -nargs=? -complete=customlist,git_switcher#_stored_session_names GswSave call git_switcher#save_session(<f-args>)
command! -nargs=? -complete=customlist,git_switcher#_stored_session_names GswLoad call git_switcher#load_session(<f-args>)
command! -bang -nargs=1 -complete=customlist,git_switcher#_stored_session_names GswDeleteSession call git_switcher#delete_session(<bang>0,<f-args>)
command! -bang -nargs=1 -complete=customlist,git_switcher#_branches Gsw call git_switcher#gsw(<bang>0,<f-args>)
command! -bang -nargs=1 -complete=customlist,git_switcher#_remote_only_branches GswRemote call git_switcher#gsw_remote(<bang>0,<f-args>)

let &cpo = s:cpo_save
unlet s:cpo_save
