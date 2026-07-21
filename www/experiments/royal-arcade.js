/* WILDCARD Royal Neon Palace preview bridge.
   Runs after the exact 6.9.14 www/index.html runtime has loaded.
   It only injects cosmetic catalogue entries and temporary preview controls. */
(function royalArcadePreviewBootstrap(){
  'use strict';
  const PREVIEW_IDS={
    theme:'theme_royal_arcade',
    table:'felt_royal_arcade',
    sly:'sly_royal_arcade'
  };
  const previewState={original:null,ready:false,swatchWrapped:false};

  function runtimeReady(){
    try{
      return typeof COSMETICS!=='undefined'
        && typeof account!=='undefined'
        && typeof applyCosmetics==='function'
        && typeof equippedId==='function'
        && typeof cosmeticById==='function'
        && typeof SLY_SKIN_FOR_COSMETIC!=='undefined';
    }catch(_){ return false; }
  }

  function addCosmetic(cosmetic){
    if(!COSMETICS.some(c=>c.id===cosmetic.id)) COSMETICS.push(cosmetic);
  }

  function installCatalogue(){
    addCosmetic({
      id:PREVIEW_IDS.theme,
      kind:'theme',
      name:'Royal Neon Palace',
      rarity:'wild',
      price:5000,
      desc:'A Figma-led royal arcade room: mint glass, violet palace light, gold cabinet trim and a clearer phone-first hierarchy.'
    });
    addCosmetic({
      id:PREVIEW_IDS.table,
      kind:'table',
      name:'Crown Grid Table',
      rarity:'wild',
      price:1200,
      desc:'A deep royal felt with crown watermark, mint circuitry and gold double-line trim.'
    });
    addCosmetic({
      id:PREVIEW_IDS.sly,
      kind:'sly',
      name:'Crown Dealer Sly',
      rarity:'wild',
      price:1800,
      desc:'Sly as a neon palace host: crown, visor, violet tuxedo and the same smug attitude.',
      skin:'royal_arcade'
    });
    SLY_SKIN_FOR_COSMETIC[PREVIEW_IDS.sly]='royal_arcade';
    if(typeof SLY_SKIN_CLASSES!=='undefined' && Array.isArray(SLY_SKIN_CLASSES)){
      if(!SLY_SKIN_CLASSES.includes('sly-skin-royal_arcade')) SLY_SKIN_CLASSES.push('sly-skin-royal_arcade');
    }
    account.cosmeticsOwned.add(PREVIEW_IDS.theme);
    account.cosmeticsOwned.add(PREVIEW_IDS.table);
    account.cosmeticsOwned.add(PREVIEW_IDS.sly);
  }

  function wrapWardrobeSwatch(){
    if(previewState.swatchWrapped || typeof swatchHtml!=='function') return;
    const originalSwatchHtml=swatchHtml;
    swatchHtml=function royalArcadeSwatch(cos){
      if(cos && cos.id===PREVIEW_IDS.theme){
        return '<div class="ward-swatch royal-arcade-theme-swatch"></div>';
      }
      return originalSwatchHtml(cos);
    };
    previewState.swatchWrapped=true;
  }

  function rememberOriginal(){
    if(previewState.original) return;
    previewState.original={
      theme:equippedId('theme'),
      table:equippedId('table'),
      sly:equippedId('sly')
    };
  }

  function setAppearance(ids){
    account.equipped={...account.equipped,...ids};
    appliedCosmeticSignature='';
    applyCosmetics(true);
    if(typeof renderWardrobe==='function' && document.getElementById('wardrobe')?.classList.contains('active')) renderWardrobe();
    if(typeof renderGame==='function' && typeof run!=='undefined' && run && document.getElementById('game')?.classList.contains('active')) renderGame(false);
    updateControlState();
  }

  function applyRoyal(){
    setAppearance({theme:PREVIEW_IDS.theme,table:PREVIEW_IDS.table,sly:PREVIEW_IDS.sly});
  }

  function applyOriginal(){
    if(previewState.original) setAppearance(previewState.original);
  }

  function updateControlState(){
    const controls=document.getElementById('royal-arcade-preview-controls');
    if(!controls) return;
    const royal=equippedId('theme')===PREVIEW_IDS.theme
      && equippedId('table')===PREVIEW_IDS.table
      && equippedId('sly')===PREVIEW_IDS.sly;
    controls.querySelector('[data-look="royal"]')?.classList.toggle('active',royal);
    controls.querySelector('[data-look="current"]')?.classList.toggle('active',!royal);
  }

  function addPreviewChrome(){
    if(!document.getElementById('royal-arcade-preview-badge')){
      const badge=document.createElement('div');
      badge.id='royal-arcade-preview-badge';
      badge.textContent='DESIGN PREVIEW · EXACT 6.9.14 RUNTIME · ROYAL NEON PALACE';
      document.body.appendChild(badge);
    }
    if(!document.getElementById('royal-arcade-preview-controls')){
      const controls=document.createElement('div');
      controls.id='royal-arcade-preview-controls';
      controls.innerHTML='<span class="preview-label">COMPARE</span>'
        +'<button type="button" data-look="current">Current 6.9.14</button>'
        +'<button type="button" data-look="royal">Royal Neon Palace</button>';
      controls.querySelector('[data-look="current"]').onclick=applyOriginal;
      controls.querySelector('[data-look="royal"]').onclick=applyRoyal;
      document.body.appendChild(controls);
    }
    updateControlState();
  }

  function install(){
    if(previewState.ready) return;
    rememberOriginal();
    installCatalogue();
    wrapWardrobeSwatch();
    addPreviewChrome();
    applyRoyal();
    previewState.ready=true;
    window.WildcardRoyalArcadePreview={applyRoyal,applyOriginal,ids:PREVIEW_IDS};
  }

  let attempts=0;
  const timer=setInterval(()=>{
    attempts++;
    if(runtimeReady()){
      clearInterval(timer);
      install();
    }else if(attempts>160){
      clearInterval(timer);
      const error=document.createElement('div');
      error.id='royal-arcade-preview-badge';
      error.textContent='ROYAL ARCADE PREVIEW COULD NOT FIND THE 6.9.14 RUNTIME';
      document.body.appendChild(error);
    }
  },100);
})();
