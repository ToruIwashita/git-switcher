" File: autoload/git_switcher.vim
" Author: Toru Hoyano <toru.iwashita@gmail.com>
" License: MIT License

let s:cpo_save = &cpo
set cpo&vim

fun! git_switcher#new(...) abort
  let obj = {
    \ '_self': 'git_switcher',
    \ '_autoload_session_behavior':    g:gsw_autoload_session,
    \ '_autodelete_sessions_bahavior': g:gsw_autodelete_sessions_if_branch_does_not_exist,
    \ '_default_project_name':         g:gsw_non_project_sessions_dir,
    \ '_default_session_name':         g:gsw_non_project_default_session_name
  \ }
  let obj.git = git_switcher#git#new()

  try
    let obj._project_name = obj.git.project()
  catch
    let obj._project_name = obj._default_project_name
  endtry

  if a:0
    let obj._session_name = a:1
  else
    try
      let obj._session_name = obj.git.current_branch()
    catch
      let obj._session_name = obj._default_session_name
    endtry
  endif

  let obj.project_session = git_switcher#project_session#new(obj._project_name, obj._session_name)
  let obj.state = git_switcher#state#new()

  fun! obj.default_project_name()
    return self._default_project_name
  endf

  fun! obj.project_name()
    return self._project_name
  endf

  fun! obj.default_session_name()
    return self._default_session_name
  endf

  fun! obj.session_name()
    return self._session_name
  endf

  fun! obj.autoload_enabled() abort
    return self._autoload_session_behavior == 'yes'
  endf

  fun! obj.autoload_enabled_with_confirmation() abort
    return self._autoload_session_behavior == 'confirm'
  endf

  fun! obj.autodelete_sessions_enabled() abort
    return self._autodelete_sessions_bahavior == 'yes'
  endf

  fun! obj.autodelete_sessions_enabled_with_confirmation() abort
    return self._autodelete_sessions_bahavior == 'confirm'
  endf

  fun! obj.non_project_default_session()
    return self.project_name() == self.default_project_name() && self.session_name() == self.default_session_name()
  endf

  fun! obj.session_locked() abort
    if self.project_session.locked()
      throw "'".self.project_session.name()."' session has been locked."
    endif
  endf

  fun! obj.lock_session() abort
    try
      call self.project_session.create_lock_file()
    catch
      throw "lock '".self.project_session.name()."' session failed."
    endtry
  endf

  fun! obj.unlock_sessions() abort
    try
      call self.project_session.delete_lock_files()
    catch
      throw 'unlock sessions failed.'
    endtry
  endf

  fun! obj.session_list() abort
    echo self.project_session.stored_session_list()
  endf

  fun! obj.branch() abort
    echo self.git.branch()
  endf

  fun! obj.remote_tracking_branch() abort
    echo self.git.remote_tracking_branch()
  endf

  fun! obj.branches() abort
    try
      return self.git.branches()
    catch
      return []
    endtry
  endf

  fun! obj.remote_only_branches() abort
    try
      return self.git.remote_only_branches()
    catch
      return []
    endtry
  endf

  fun! obj.fetch_project() abort
    echo 'fetching remote.'
    call self.git.fetch()
    redraw!
    echo 'fetched.'
  endf

  fun! obj.pull_current_branch() abort
    echo "pulling '".self.git.current_branch()."' branch."
    call self.git.pull_current_branch()
    checktime
    redraw!
    echo 'pulled.'
  endf

  fun! obj.save_session() abort
    if self.non_project_default_session() && confirm("save '".self.project_session.name()."' (non project default) session?", "&Yes\n&No", 0) != 1
      return 1
    endif

    call self.session_locked()
    call self.project_session.store()
    echo "saved '".self.project_session.name()."' session."

    if !self.git.inside_work_tree() || (self.project_session.session_name() != self.git.current_branch())
      return 1
    endif

    call self.unlock_sessions()
    call self.lock_session()
  endf

  fun! obj.load_session() abort
    call self.session_locked()
    if !self.project_session.exists()
      throw "'".self.project_session.name()."' session file does not exist."
    endif

    call self.clear_state()
    call self.unlock_sessions()
    call self.project_session.restore()
    echo "loaded '".self.project_session.name()."' session."

    call self.lock_session()
  endf

  fun! obj.autoload_session() abort
    if !self.git.inside_work_tree() || !self.project_session.exists()
      return 1
    endif
    call self.session_locked()

    if self.autoload_enabled() || (self.autoload_enabled_with_confirmation() && confirm("load '".self.project_session.name()."' session?", "&Yes\n&No", 0) == 1)
      call self.load_session()
    end
  endf

  fun! obj.autodelete_sessions_if_branch_does_not_exist() abort
    let bang = 0
    if self.autodelete_sessions_enabled() | let bang = 1 | end

    if self.autodelete_sessions_enabled() || self.autodelete_sessions_enabled_with_confirmation()
      call self.delete_sessions_if_branch_does_not_exist(bang)
      redraw!
    end
  endf

  fun! obj.switch(bang, source, branch) abort
    if !self.git.branch_exists(a:branch)
      if confirm("create '".a:branch."' branch based on '".self.git.current_branch()."'?", "&Yes\n&No", 0) != 1
        return 1
      endif
      redraw!

      if a:source ==# 'remote'
        call self.fetch_project()
        redraw!
        call self.git.create_remote_trancking_branch(a:branch)
      elseif a:source ==# 'local'
        call self.git.create_branch(a:branch)
      end
    endif

    if !a:bang && confirm("save '".self.project_session.name()."' session?", "&Yes\n&No", 0) == 1
      redraw!
      call self.save_session()
    endif
    redraw!

    redraw!
    echo "checking out files."

    call self.git.switch(a:branch)

    let self.project_session = git_switcher#project_session#new(self.git.project(), a:branch)

    if a:bang
      checktime
      redraw!
      echo "switched to '".a:branch."' branch."
      return 1
    endif

    redraw!
    if self.project_session.exists()
      call self.load_session()
      let res_message = "switched to '".a:branch."' branch and loaded session."
    else
      let res_message = "switched to '".a:branch."' branch."
    endif

    redraw!
    echo res_message
  endf

  fun! obj.stored_session_names() abort
    return self.project_session.stored_session_names()
  endf

  fun! obj.stored_project_sessions() abort
    return map(self.stored_session_names(), 'git_switcher#project_session#new(self.project_name(), v:val)')
  endf

  fun! obj.delete_session(...) abort
    let bang = 0
    if a:0 | let bang = a:1 | endif

    if !bang && confirm("delete '".self.project_session.name()."' session?", "&Yes\n&No", 0) != 1
      return 1
    endif

    call self.project_session.destroy()
  endf

  fun! obj.delete_sessions_if_branch_does_not_exist(...) abort
    let bang = 0
    if a:0 | let bang = a:1 | endif
     
    for project_session in self.stored_project_sessions()
      if self.git.branch_exists(project_session.session_name())
        continue
      endif
 
      if !bang && confirm("delete '".project_session.name()."' session?", "&Yes\n&No", 0) != 1
        continue
      endif
 
      call project_session.destroy()
    endfor
  endf

  fun! obj.clear_state() abort
    call self.state.delete_all_buffers()
    call self.unlock_sessions()
    redraw!
    echo 'cleared session state.'
  endf

  return obj
endf

fun! git_switcher#session_list()
  try
    let git_switcher = git_switcher#new()
    call git_switcher.session_list()
  catch
    redraw!
    echo v:exception
  endtry
endf

fun! git_switcher#branch()
  try
    let git_switcher = git_switcher#new()
    call git_switcher.branch()
  catch
    redraw!
    echo v:exception
  endtry
endf

fun! git_switcher#remote_tracking_branch()
  try
    let git_switcher = git_switcher#new()
    call git_switcher.remote_tracking_branch()
  catch
    redraw!
    echo v:exception
  endtry
endf

fun! git_switcher#fetch_project()
  try
    let git_switcher = git_switcher#new()
    call git_switcher.fetch_project()
  catch
    redraw!
    echo v:exception
  endtry
endf

fun! git_switcher#pull_current_branch()
  try
    let git_switcher = git_switcher#new()
    call git_switcher.pull_current_branch()
  catch
    redraw!
    echo v:exception
  endtry
endf

fun! git_switcher#save_session(...)
  try
    let git_switcher = call('git_switcher#new', a:000)
    call git_switcher.save_session()
  catch
    redraw!
    echo v:exception
  endtry
endf

fun! git_switcher#load_session(...)
  try
    let git_switcher = call('git_switcher#new', a:000)
    call git_switcher.load_session()
  catch
    redraw!
    echo v:exception
  endtry
endf

fun! git_switcher#gsw(bang,branch)
  try
    let git_switcher = git_switcher#new()
    call git_switcher.switch(a:bang, 'local', a:branch)
  catch
    redraw!
    echo v:exception
  endtry
endf

fun! git_switcher#gsw_remote(bang,branch)
  try
    let git_switcher = git_switcher#new()
    call git_switcher.switch(a:bang, 'remote', a:branch)
  catch
    redraw!
    echo v:exception
  endtry
endf

fun! git_switcher#clear_stete()
  try
    let git_switcher = git_switcher#new()
    call git_switcher.clear_state()
  catch
    redraw!
    echo v:exception
  endtry
endf

fun! git_switcher#delete_session(bang,branch)
  try
    let git_switcher = git_switcher#new(a:branch)
    call git_switcher.delete_session(a:bang)
  catch
    redraw!
    echo v:exception
  endtry
endf

fun! git_switcher#delete_sessions_if_branch_does_not_exist(bang)
  try
    let git_switcher = git_switcher#new()
    return git_switcher.delete_sessions_if_branch_does_not_exist(a:bang)
  catch
    redraw!
    echo v:exception
  endtry
endf

fun! git_switcher#autocmd_for_vim_enter()
  try
    let git_switcher = git_switcher#new()
    call git_switcher.autodelete_sessions_if_branch_does_not_exist()
    call git_switcher.autoload_session()
  catch
    redraw!
    echo v:exception
  endtry
endf

fun! git_switcher#autocmd_for_vim_leave()
  try
    let git_switcher = git_switcher#new()
    call git_switcher.unlock_sessions()
  catch
    redraw!
    echo v:exception
  endtry
endf

fun! git_switcher#_branches(...)
  try
    let git_switcher = git_switcher#new()
    return filter(git_switcher.branches(), 'v:val =~ "^'.fnameescape(a:1).'"')
  catch
    redraw!
    echo v:exception
  endtry
endf

fun! git_switcher#_remote_only_branches(...)
  try
    let git_switcher = git_switcher#new()
    return filter(git_switcher.remote_only_branches(), 'v:val =~ "^'.fnameescape(a:1).'"')
  catch
    redraw!
    echo v:exception
  endtry
endf

fun! git_switcher#_stored_session_names(...)
  try
    let git_switcher = git_switcher#new()
    return filter(git_switcher.stored_session_names(), 'v:val =~ "^'.fnameescape(a:1).'"')
  catch
    redraw!
    echo v:exception
  endtry
endf

let &cpo = s:cpo_save
unlet s:cpo_save
