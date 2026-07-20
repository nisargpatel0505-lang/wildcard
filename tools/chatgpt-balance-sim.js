'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');

const args=process.argv.slice(2);
const argValue=prefix=>{const item=args.find(value=>value.startsWith(prefix));return item?item.slice(prefix.length):null};
const runs=Number(argValue('--runs=')||100);
const cohortFilter=argValue('--cohort=')||'all';
const outputArg=argValue('--output=');
const assertFix=args.includes('--assert-fix');
if(!Number.isInteger(runs)||runs<20||runs>5000)throw new Error('runs must be an integer from 20 to 5000');
const html=fs.readFileSync(path.join(__dirname,'..','www','index.html'),'utf8');
function el(){const s=new Set();return{children:[],style:{},dataset:{},textContent:'',innerHTML:'',value:'',disabled:false,hidden:false,offsetParent:{},classList:{add:(...x)=>x.forEach(y=>s.add(y)),remove:(...x)=>x.forEach(y=>s.delete(y)),contains:x=>s.has(x),toggle:(x,f)=>{const o=f===undefined?!s.has(x):!!f;o?s.add(x):s.delete(x);return o}},appendChild(x){this.children.push(x);return x},remove(){},focus(){},setAttribute(){},removeAttribute(){},addEventListener(){},querySelector(){return el()},querySelectorAll(){return[]},getBoundingClientRect(){return{x:0,y:0,width:320,height:480,bottom:480}}}}
const em=new Map(),doc={body:el(),hidden:false,activeElement:null,getElementById(i){if(!em.has(i))em.set(i,el());return em.get(i)},createElement:el,querySelector:el,querySelectorAll:()=>[],addEventListener(){}};
const sm=new Map(),ls={getItem:k=>sm.get(k)||null,setItem:(k,v)=>sm.set(k,String(v)),removeItem:k=>sm.delete(k)};
function mulberry(a){return()=>{a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
let hr=mulberry(0x56072026);const M=Object.create(Math);M.random=()=>hr();
const c={console,Math:M,JSON,Date,Set,Map,WeakMap,Promise,Object,Array,Number,String,Boolean,RegExp,Error,TypeError,Uint32Array,TextEncoder,parseInt,parseFloat,isNaN,Infinity,NaN,document:doc,localStorage:ls,navigator:{},location:{hostname:'localhost'},history:{replaceState(){},pushState(){}},screen:{width:390,height:844},matchMedia:()=>({matches:true}),getComputedStyle:()=>({}),confirm:()=>true,alert(){},fetch:async()=>({ok:false,json:async()=>({})}),setTimeout:()=>0,clearTimeout(){},setInterval:()=>0,clearInterval(){},requestAnimationFrame:f=>{f(0);return 0},cancelAnimationFrame(){},addEventListener(){},removeEventListener(){},dispatchEvent(){return true},performance:{now:()=>Date.now()},structuredClone:global.structuredClone,btoa:v=>Buffer.from(v,'binary').toString('base64'),atob:v=>Buffer.from(v,'base64').toString('binary')};c.window=c;c.globalThis=c;c.scrollTo=()=>{};vm.createContext(c);
let live=[...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)].at(-1)[1];live=live.slice(0,live.indexOf('// ---- Global daily leaderboard'));
live+=`;globalThis.S={setRun:v=>run=v,getRun:()=>run,setPending:v=>pendingGauntlet=!!v,newRunState,baseCardSet,buildDeck,dealFreshHand,refillHand,assignModifier,effHands,effDiscards,effMaxSelect,stageTarget,scoreHand,evaluateHand,allSameColor,runReward,interestCapForHeat,normalizeSupplyState,supplyPrice,supplyEscalationStep,supplySurcharge,copierCardBlockedReason,rollJokerOffers,rollSupplyOffers,shopBuyLimit,shopPrice,JOKERS,SUPPLIES,MAX_JOKERS,MAX_HAND_LEVEL,MIN_RUN_DECK_SIZE,HAND_SIZE,GRADES,INTEREST_PER,account,getShop:()=>shopOffers,getSup:()=>supplyOffers,setShop:v=>shopOffers=v};`;
vm.runInContext(live,c,{timeout:120000});const S=c.S;
function combos(a,n){const o=[],p=[];(function w(i){if(p.length===n){o.push(p.slice());return}for(let k=i;k<=a.length-(n-p.length);k++){p.push(a[k]);w(k+1);p.pop()}})(0);return o}
function best(){const r=S.getRun();let b=null;for(let n=1;n<=Math.min(S.effMaxSelect(),r.hand.length);n++)for(const cards of combos(r.hand,n)){if(n>1&&n<5){const t=S.evaluateHand(cards);if(t==='High Card'&&!S.allSameColor(cards))continue}const z=S.scoreHand(cards,false);if(!b||z.total>b.z.total)b={cards,z}}return b}
function dominant(cards){const q={};for(const x of cards)q[x.suit]=(q[x.suit]||0)+1;return Object.keys(q).sort((a,b)=>q[b]-q[a])[0]}
function discard(){const r=S.getRun(),cnt={};for(const x of r.hand)cnt[x.rank]=(cnt[x.rank]||0)+1;const su=dominant(r.hand);const v=r.hand.map(x=>({x,v:(cnt[x.rank]-1)*18+(x.suit===su?7:0)+x.value*.35+(x.enh?8:0)})).sort((a,b)=>b.v-a.v);const keep=new Set(v.slice(0,Math.min(4,Math.max(2,r.hand.length-5))).map(y=>y.x)),toss=r.hand.filter(x=>!keep.has(x)).slice(0,5);if(!toss.length)return false;r.hand=r.hand.filter(x=>!toss.includes(x));r.discardsLeft--;S.refillHand();return true}
function jval(j){let v=j.xMult?130:0;v+=j.addMult?85:0;v+=j.rankMod?45:0;v+=j.onScored?35:0;v+=j.onHeatClear?20:0;if(j.rarity==='wild')v+=25;if(['polish','lastcall','allin','survivor','wire','flushfund','boostfiend','master_class','glass_joystick'].includes(j.id))v+=70;return v}
function shop(){const r=S.getRun();r.boughtThisShop=false;r.shopBuysUsed=0;r.suppliesBoughtThisShop=[];r.pendingShopJoker=null;S.normalizeSupplyState();S.rollJokerOffers(true);S.rollSupplyOffers();for(let n=0;n<S.shopBuyLimit();n++){const offers=S.getShop().filter(j=>!r.jokers.some(x=>x.id===j.id)).sort((a,b)=>jval(b)-jval(a));if(!offers.length)break;const j=offers[0],price=S.shopPrice(j.price);let idx=-1,refund=0;if(r.jokers.length>=S.MAX_JOKERS){idx=r.jokers.map((x,i)=>[i,jval(x)]).sort((a,b)=>a[1]-b[1])[0][0];refund=Math.max(1,Math.floor(r.jokers[idx].price/2));if(jval(j)<=jval(r.jokers[idx])*1.08)break}if(r.runCoins+refund<price)break;r.runCoins+=refund-price;if(idx>=0)r.jokers[idx]=j;else r.jokers.push(j);S.setShop(S.getShop().filter(x=>x.id!==j.id))}
 for(const s of S.getSup()){const price=S.supplyPrice(s);if(r.runCoins<price)continue;let used=false;if(s.id==='boost'){const types=Object.entries(r.handTypeCounts).sort((a,b)=>b[1]-a[1]);const t=types[0]?.[0]||'Pair';if((r.handLevels[t]||0)<S.MAX_HAND_LEVEL){r.handLevels[t]=(r.handLevels[t]||0)+1;r.boostsBought++;used=true}}else if(s.id==='scalpel'&&r.cards.length>32){let i=0;for(let k=1;k<r.cards.length;k++)if(r.cards[k].value<r.cards[i].value)i=k;r.cards.splice(i,1);r.destroyedCount++;used=true}else if(s.id==='copier'){const cand=r.cards.filter(x=>!S.copierCardBlockedReason(x)).sort((a,b)=>b.value-a.value)[0];if(cand&&M.random()<.3){r.cards.push({...cand});r.copiedCount++;used=true}}if(used){r.runCoins-=price;r.supplyPurchaseCounts[s.id]=(r.supplyPurchaseCounts[s.id]||0)+1;r.supplyPriceEscalation=S.supplySurcharge()+S.supplyEscalationStep();break}}
}
function setup(stage){const r=S.getRun();r.stage=stage;r.stageScore=0;r.handsPlayedThisStage=0;r.prevHandType=null;S.assignModifier();r.handsLeft=S.effHands();r.discardsLeft=S.effDiscards();r.deck=S.buildDeck();r.heatDeck=r.deck.slice();S.dealFreshHand()}
function one(unlocked,seed){hr=mulberry(seed);S.setPending(false);const r=S.newRunState();S.setRun(r);r.cards=S.baseCardSet();r.jokers=[];r.jokerState={};r.rngSeed=seed>>>0;r.rngCounters={deck:0,shop:0,mods:0,luck:0,boss:0};S.account.unlocked=new Set(unlocked);const starters=S.JOKERS.filter(j=>S.account.unlocked.has(j.id)).sort((a,b)=>jval(b)-jval(a));if(starters[0])r.jokers=[starters[0]];for(let st=1;st<=12;st++){setup(st);let g=0;while(r.stageScore<S.stageTarget()&&r.handsLeft>0&&r.hand.length&&g++<30){const b=best();if(!b)break;const need=(S.stageTarget()-r.stageScore)/Math.max(1,r.handsLeft);if(r.discardsLeft>0&&r.deck.length&&b.z.total<need*.78){if(discard())continue}const z=S.scoreHand(b.cards,true);r.stageScore+=z.total;r.totalScore+=z.total;r.bestPlay=Math.max(r.bestPlay,z.total);r.handTypeCounts[z.handType]=(r.handTypeCounts[z.handType]||0)+1;r.handsLeft--;r.handsPlayedThisStage++;r.prevHandType=z.handType;for(const j of r.jokers)if(j.onScored)j.onScored(z.ctx);r.hand=r.hand.filter(x=>!b.cards.includes(x));S.refillHand()}if(r.stageScore<S.stageTarget())return{win:false,fail:st,cleared:st-1};r.stagesCleared++;const grade=S.GRADES[Math.min(4,Math.max(1,r.handsPlayedThisStage))];const interest=(r.modifier&&((r.modifier.id==='shakedown')||(r.modifier.mods||[]).some(x=>x.id==='shakedown')))?0:Math.min(S.interestCapForHeat(),Math.floor(r.runCoins/S.INTEREST_PER));const shake=interest===0&&r.modifier&&((r.modifier.id==='shakedown')||(r.modifier.mods||[]).some(x=>x.id==='shakedown'));r.runCoins+=(shake?Math.max(1,Math.floor(S.runReward(st)/2)):S.runReward(st))+interest+grade.bonus;for(const j of r.jokers)if(j.onHeatClear)j.onHeatClear();r.inflation=!!(r.modifier&&((r.modifier.id==='inflation')||(r.modifier.mods||[]).some(x=>x.id==='inflation')));if(st<12){shop();r.inflation=false}}return{win:true,fail:0,cleared:12}}
const all=S.JOKERS.map(j=>j.id),free=S.JOKERS.filter(j=>j.unlock===0).map(j=>j.id),prog=S.JOKERS.filter(j=>j.unlock===0||j.unlock<=80).map(j=>j.id);
const definitions=[['new_player',free],['some_progression',prog],['full_unlock',all]];
const requested=cohortFilter==='all'?definitions:definitions.filter(([name])=>name===cohortFilter);
if(!requested.length)throw new Error('unknown cohort: '+cohortFilter);
const cohorts=requested.map(([name,ids])=>{
  const cohortIndex=definitions.findIndex(([candidate])=>candidate===name),outcomes=[];
  for(let i=0;i<runs;i++)outcomes.push(one(ids,(0x56070000+cohortIndex*100000+i)>>>0));
  const wins=outcomes.filter(x=>x.win).length;
  return{name,unlocked:ids.length,runs,wins,winRate:+(wins*100/runs).toFixed(2),avgCleared:+(outcomes.reduce((sum,x)=>sum+x.cleared,0)/runs).toFixed(2),failAt:outcomes.reduce((result,x)=>(!x.win&&(result[x.fail]=(result[x.fail]||0)+1),result),{})};
});
const result={
  generatedAt:new Date().toISOString(),source:'www/index.html',runsPerCohort:runs,cohortFilter,cohorts,
  methodology:'Deterministic greedy bots enumerate legal plays, discard weak hands, value multiplier engines, buy affordable Jokers, and exercise the patched supply/deck rules.',
  priorCoverageGaps:[
    'The old complete-run loop stopped at Heat 12 (or Gauntlet Heat 8), so it never exercised Endless or post-50 modifiers.',
    'The old Scalpel bot stopped thinning at 42 cards, far above the old nine-card exploit floor.',
    'The old Copier bot mutated run.cards directly and bypassed picker eligibility for enhanced cards.',
    'The old supply model checked per-item +2 history rather than the requested global surcharge.',
    'No adversarial strategy deliberately built repeated same-suit three-card Shortcut sequences.'
  ]
};
if(assertFix){
  assert.equal(cohorts.length,requested.length);
  for(const row of cohorts){assert.equal(row.runs,runs);assert.equal(Object.values(row.failAt).reduce((sum,n)=>sum+n,0)+row.wins,runs);}
}
if(outputArg){
  const outputPath=path.resolve(__dirname,'..',outputArg),reportPath=outputPath.replace(/\.json$/i,'.md');
  fs.mkdirSync(path.dirname(outputPath),{recursive:true});
  fs.writeFileSync(outputPath,JSON.stringify(result,null,2)+'\n');
  const rows=cohorts.map(row=>`| ${row.name} | ${row.unlocked} | ${row.runs} | ${row.wins} | ${row.winRate}% | ${row.avgCleared} |`).join('\n');
  fs.writeFileSync(reportPath,`# WILDCARD ChatGPT 5.6 balance simulation\n\n| Cohort | Unlocked Jokers | Runs | Beat Heat 12 | Win rate | Avg cleared |\n| --- | ---: | ---: | ---: | ---: | ---: |\n${rows}\n\n## Why the old simulations missed the reported flaws\n\n${result.priorCoverageGaps.map(item=>'- '+item).join('\n')}\n`);
}
console.log(JSON.stringify(result,null,2));
