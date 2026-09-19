export function createModal(content){
  const overlay = document.createElement('div')
  overlay.style = 'position:fixed;inset:0;background:rgba(0,0,0,.4);display:flex;align-items:center;justify-content:center;z-index:9999'
  const box = document.createElement('div')
  box.style = 'background:#fff;border-radius:.75rem;max-width:480px;width:90%;padding:1.25rem;box-shadow:0 10px 30px rgba(0,0,0,.2)'
  box.innerHTML = content
  overlay.appendChild(box)
  overlay.addEventListener('click', e=>{ if(e.target===overlay) document.body.removeChild(overlay) })
  document.body.appendChild(overlay)
  return { close: ()=>document.body.removeChild(overlay) }
}
