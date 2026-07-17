# WILDCARD v6.9.10 Revenue Sensitivity

This is a planning model, not a forecast. The current build uses Google's demo AdMob IDs and test mode, so its production ad revenue is **£0** until owner-created AdMob IDs are configured and approved.

## Monthly scenario output

| Daily active players | Low | Base | High |
| ---: | ---: | ---: | ---: |
| 50 | £8.79 | £42.3 | £111.19 |
| 200 | £35.14 | £169.2 | £444.75 |
| 1,000 | £175.73 | £846 | £2,223.75 |
| 10,000 | £1,757.25 | £8,460 | £22,237.5 |

Totals combine modeled rewarded/interstitial ads and modeled IAP proceeds after the scenario Play fee, but before VAT/tax, refunds, chargebacks and foreign exchange.

## Assumptions

- **Low:** 75% fill; 1 rewarded views at £5 eCPM; 1.5 interstitial views at £1.5 eCPM per DAU/day; MAU/DAU 2; 0.3% monthly payer conversion; £3 gross monthly ARPPU; 30% Play fee.
- **Base:** 90% fill; 1.8 rewarded views at £10 eCPM; 2.5 interstitial views at £4 eCPM per DAU/day; MAU/DAU 3; 0.8% monthly payer conversion; £5 gross monthly ARPPU; 25% Play fee.
- **High:** 95% fill; 2.5 rewarded views at £15 eCPM; 3.5 interstitial views at £8 eCPM per DAU/day; MAU/DAU 4; 1.5% monthly payer conversion; £7 gross monthly ARPPU; 15% Play fee.

## Source catalogue

- coins_250: 250 coins at £0.99 in source
- coins_600: 600 coins at £1.99 in source
- coins_1600: 1,600 coins at £4.99 in source
- coins_3600: 3,600 coins at £9.99 in source
- coins_8500: 8,500 coins at £19.99 in source
- remove_ads: £2.99 in source

Source SHA-256: `116d1878b733667b2fdb87c28e9ed38b5f8010288894e11bbebe9cf9a4c81521`

Model SHA-256: `121e632aeadacd3707a75d4821cab9d37a3af609dd6b6bc26b2af50395c269aa`
