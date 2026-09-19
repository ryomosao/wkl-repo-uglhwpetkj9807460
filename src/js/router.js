import { qs, load } from './utils/dom.js'

const routes = {
  '/': 'pages/home.html',
  '/about': 'pages/about.html',
  '/contact': 'pages/contact.html'
}

function render(path){
  const view = qs('#view')
  const file = routes[path] || routes['/']
  load(view, file)
}

export function startRouter(){
  function onChange(){
    const hash = location.hash.replace('#','') || '/'
    render(hash)
  }
  window.addEventListener('hashchange', onChange)
  onChange()
}
