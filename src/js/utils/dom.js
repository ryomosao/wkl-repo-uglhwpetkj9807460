export function qs(selector, scope=document){return scope.querySelector(selector)}
export function qsa(selector, scope=document){return Array.from(scope.querySelectorAll(selector))}
export function load(target, url){return fetch(url).then(r=>r.text()).then(html=>{target.innerHTML=html;})}
