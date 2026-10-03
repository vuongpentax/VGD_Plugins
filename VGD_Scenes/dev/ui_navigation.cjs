// Existing behavior tests reveal controls through the new navigation/disclosures.
// Flow-specific tests exercise the navigation explicitly without this helper.
module.exports=page=>{
 const click=page.click.bind(page);
 async function reveal(selector){
  if(selector==='[data-tab="sections"]'){await click('[data-tab="views"]');return '[data-create="sections"]';}
  const target=page.locator(selector).first();
  const panel=await target.evaluate(el=>el.closest('.tab')?.id || ({generate:'views',section:'sections',goCompose:'scenes',updateCurrentView:'compose',exportButton:'export'}[el.id]));
  if(panel && !await target.isVisible()){
   if(panel==='sections'){await click('[data-tab="views"]');await click('[data-create="sections"]');}
   else await click('[data-tab="'+panel+'"]');
  }
  const parents=await target.locator('xpath=ancestor::details').all();
  for(const parent of parents){if(!await parent.evaluate(el=>el.open))await parent.locator(':scope > summary').click();}
  return selector;
 }
 for(const method of ['click','fill','selectOption','check','uncheck','press','focus']){
  const original=page[method].bind(page);
  page[method]=async(selector,...args)=>original(await reveal(selector),...args);
 }
};
