import { qs, load } from './utils/dom.js'
import { startRouter } from './router.js'

async function boot(){
  await load(qs('#site-header'), 'components/header.html')
  await load(qs('#site-footer'), 'components/footer.html')
  startRouter()
}

boot()
