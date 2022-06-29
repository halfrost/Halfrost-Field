# Francium-based PDN

## Why we need Pseudo-Delta Neutral Hedging Strategy?

- In the pursuit for leveraged yields, we can choose to open long or short farming positions according to our view on the market. But, it contains a lot of risk of liquidation. So we need more **neutral** and **lower-risk** strategy.
- In **CeFi** field, Delta means that differentials in price of the assets in your portfolio. Delta-neutral means that we expect overall delta of your assets to total to zero. In other words, you can’t lose money, and you won’t gain either in CeFi.
- In **DeFi** field, you can still earn profits from neutral positions when you farm using some strategy because you’re providing liquidity and will be rewarded with the yields. Thus the Pseudo-Delta Neutral Hedging Strategy was born.
- **Pseudo-Delta Neutral Hedging Strategy** takes a long and short position in an asset simultaneously to minimize the effect on your portfolio when the underlying asset’s price moves. With this Delta-neutral strategy, you can expect higher capital utilization rate and profit.
- **Neutral Farming contain PDN Hedging strategy(3x) and Borrow Farming(2x).** This document only talk about PDN Hedging strategy(3x).

## When will the position in this Pseudo-Delta Neutral Hedging Strategy be liquidated?

- In conclusion: because the stop-losses will execute when you have deployed this strategy on Francium.
- In general, this is where the pseudo nuance comes into the picture — when you open a pseudo-delta neutral position, you are actually betting for the asset’s price to move within a particular range. In other words, the two true Delta neutrals are stable and profitable as long as they are within acceptable limits. By design, the neutral strategy’s default stop-loss threshold is at 10% of your position. Total liquidation of a position is avoided with this protection strategy.
    
    For example, with Francium stop-loss mechanism, the asset you are invested in with this hedging strategy will be returned to you if equity value moves 10% below your entry. if you invested $1,000, stop-loss triggers when your equity value falls to $900, and the remaining asset will go to your wallet after deducting a certain amount of robot fees.
    

## Details of Delta-Neutral Hedging Strategy

There are two Integrate yield farming from liquidity pools: **Raydium** and **Orca**. The underlying assets selected for the Pseudo-Delta Neutral Hedging Strategy are **$whETH** and **$USDC.** We select these assets as they are relatively stable and have excellent leverage returns.

- How is the liquidity pools work? Harvest and then re-invest automatically. [Raydium Fusion Pool](https://raydium.io/fusion/) and [Orca Aquafarms Pool](https://www.orca.so/pools)

![](https://img.halfrost.com/Blog%2FArticleImage%2F155_1.png)

- Neutral Hedge Strategy position setup procedures, For example:
1. Begin by depositing a total of $400 USDC into the following positions:
2. Deposit $100 USDC in Position: 3X ETH/USDC (borrowing USDC)
    
    You have deposited $100 equivalent USDC and borrowed $200 USDC. The total position value is $300 USDC. Since it is a 50%-50% position setting, you will have a $300 - $150 = $150 cost ETH LONG exposure.
    
3. Deposit $150 ETH & $150 USDC for LP tokens.
4. Stake LP tokens into the farming pool.
    
    **So far, long position part is staked into the farming pool.**
    
5. Deposit $300 USDC in Position: 3X ETH/USDC (borrowing ETH)
    
    You have deposited $300 USDC and borrowed $600 equivalent ETH. The total position value is $900 USDC. Since it is a 50%-50% position setting, you will have a $600 - $450 = $150 cost ETH SHORT exposure.
    
6. Deposit $450 ETH & $450 USDC for LP tokens.
7. Stake LP tokens into the farming pool.
    
    **So far, short position part is staked into the farming pool.**
    

Both the long position and short exposures are hedged.

![](https://img.halfrost.com/Blog%2FArticleImage%2F155_2.png)

According to the above example, we can get $150 whETH long position and $150 whETH short position.

- About profit

When closing the position, the following steps are followed. Let's liquidate the long position first:

1. Redeem all LP tokens for ETH & USDC.
2. Sell all ETH for USDC.
3. Repay **N(Y-1)** USDC.
4. You get the remaining USDC.

Assumption we take **P** as the price of ETH, using the amount of USDC as a unit. Initially, we holds **N** USDC, and the price of ETH is **P₀**. When he participated in LYF with leverage **Y.** Based on the AMM formula, when **P** changes, the amount of USDC we can withdraw by redeeming the LP token is:

$$
NY\sqrt{\frac{p}{p_{0}}}
$$

So when you close the position, the profit by long we get is:

$$
NY(\sqrt{\frac{p}{p_{0}}}-1)
$$

USDC Profits on 1x/2x/3x Margin VS Traditional 1x function curve:

![](https://img.halfrost.com/Blog%2FArticleImage%2F155_3.png)


Then liquidate the short position:

1. Redeem All LP tokens for ETH & USDC
2. Sell all ETH for USDC
3. Repay **M(Y-1)** USDC
4. You get the remaining USDC

Initially, we holds **M** USDC, whose initial price is **P₀**, when he participated in LYF with leverage **Y.** Based on the AMM formula, when **P** changes, the amount of USDC we can withdraw by redeeming the LP token is:

$$
MY\sqrt{\frac{p_{0}}{p}}
$$

The total worth of LP tokens are: (amount * price)

$$
MY\sqrt{\frac{p_{0}}{p}}*p = MY\sqrt{p_{0}p}
$$

When you the close position, the profit you get is:

$$
MY(\sqrt{p_{0}p} - p)
$$

Token A 1x/2x/3x Margin Profit, with Token A as Principal

![](https://img.halfrost.com/Blog%2FArticleImage%2F155_4.png)


From the above figures, you can see the LYF curve is smoother. When the leverage is equal, long & shorting with LYF can reduce the risk when the price is going up/down. When the leverage reaches twice that of the traditional short, it begins to suppress the profit of traditional longing and shorting within a certain range, but the cost is higher when prices fall or rise, or when capital usage is higher. It may look like a simple long/short strategy, but there is an important factor we haven’t taken into account: farming yield, or maybe what we can call self-adjusting leverage. Because our LP tokens keep earning rewards and those rewards are reinvested into our LP tokens, the borrowed tokens are going to take a lower and lower proportion relative to the capital, so we have decreasing leverage. For example, if token A is not likely to fluctuate within a short time, LYF longing/shorting can make it more resistant to market volatility in the future. In a constant APR auto-compound model, the profit can be demonstrated as below:


![](https://miro.medium.com/max/700/1*hH8-Tt1ZleR-DVrZ76n35A.gif)

If we combine long and short to see profit, we can get a curve similar to the following figure:

![](https://img.halfrost.com/Blog%2FArticleImage%2F155_5.jpg)


In the graph above, the horizontal axis shows the price movement of ETH and the vertical axis shows the profit/loss (%) of the position.

As you can see from the picture above. If we only invest 10 days, Our profit is the highest when the whETH price is the same as when we bought it. The whETH on the chart is $1086, and the Equity value is 2.49%. We are still profitable when whETH fluctuates between -22% and +29%. When whETH falls below -22%, we start to lose money, and when whETH rises above +29%, we start to lose money.

![](https://img.halfrost.com/Blog%2FArticleImage%2F155_6.jpg)

As our investment days get longer, the range of returns that can be made becomes larger and larger. As shown above, if you choose to invest for 365 days. Then there is a huge range of gains.

## When will I use this Neutral Strategy?

When you believe the assets in the pair will neither rise nor drop dramatically in the coming period.****

## What is the risk of this Neutral Strategy?

Risk to the Yield Farmers:

- Price impact when entering/exiting a position
- Impermanent Loss (IL)
    
    What is impermanent loss: [https://coinmarketcap.com/alexandria/glossary/impermanent-loss](https://coinmarketcap.com/alexandria/glossary/impermanent-loss)
    
    impermanent loss calculator: [https://defiyield.app/advanced-impermanent-loss-calculator](https://defiyield.app/advanced-impermanent-loss-calculator)
    
- Negative APY
- Liquidation

Risk to the Lenders:

- Asset Return Timing
    
    For example, if the utilization is too high and most of the assets in the pool are occupied, users may not withdraw their deposits on time until leveraged farmers repay their debt.
    
- Bad Debt
- Loss of Capital

There is a 10% maximum drawdown when you open a Neutral Strategy position on Francium.

**Details:**

If the price of ETH varies sharply (for example, rises > 60% or drops > 50%) ,your position will be at a loss.

Your position will be closed at the maximum 10 % drawdown of the total position value to avoid further loss.

The 10% drawdown only applies to the market-neutral strategy, not positions where you manually selected the amount of leverage.

