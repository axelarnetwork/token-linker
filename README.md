# Token Linker

This repo is to be used to link any tokens across two or more different EVM compatible chains on a one-to-one basis using only Axelar's general message passing. These tokens can be:

- A pre-existing ERC20, which means they need to be locked/unlocked on chain. (**LockUnlock**)
- A newly deployed ERC20, which can be minted/burn by our token linker (and oly our token linker). (**MintBurn**)
- The native currency of a chain, such as ETH for Ethereum. (**Native**)

## Design

The token linker proxy contracts will be deployed with the same address on each of the supported chains. This can be done in two ways:

- Use the same account on each chain **with the same nonce**.
- Use the same account on each chain with the predeployed `ConstAddressDeployer` smart contract.

The later is used in this example because it makes testing a bit easier, as ensuring the same nonce across multiple chains when testing is quite hard, or requires spawning and funding new accounts for each iteration, which is also cumbersome. Feel free however to use the first option if you would not like to depend on us to deploy the `ConstAddressDeployer` (which needs to be done from the same address and nonce).

These token linker proxies will all point to implementations which can be different, depending on the use case we are going for on each chain. The token linker contract can either 
- Receive the appropriate token, and send a message to the chain specified with the amount received as well as the address that is to receive the token.
- Receive a message from a token linker on another chain, and give an of token to a user as specified by the message received.

Since Axelar passes the sender address of any message we only need to check that the sender address matches our own when we receive a message.

## Detailed Example Use: Subnet

For this example we will assume you are launching an Avalanche subnet and want your native subnet token to be linked to a pre-existing ERC20 on the C-chain. Let's call the token Subnet Token (ST). Let's also assume you want ST to be able to be bridged to Ethereum also. 

### Deployed Contracts

You need to deploy the same `TokenLinkerProxy` contract on Ethereum, Avalanche and your subnet. Additionaly you need to deploy a `TokenLinkerLockUnlock` on Avalanche, specifying the address of the pre-existing ST ERC20. On your subnet you need to deploy a `TokenLinkerNative` and finally on Ethereum you first need to deploy a new ERC20 that can be minted/burnt only by it's owner and a `TokenLinkerMintBurn` which will own the ERC20 deployed.

### Air Drops and Getting to 'one-to-one' Status

Let's first define some variables:

- Let `X` be the total amount of ST circulating on Avalanche, which includes the amount locked up by the token linker.
- Let `Y` be the total amount of native ST circulating on the subnet, which includes the amount locked up by the token linker.
- Let `A` be the amount of ST locked by the token linker on Avalanche.
- Let `B` be the amount of ST locked by the token linker on the subnet.
- let `M` be the amount of ST minted by the token linker on Ethereum.

We, at all times, we have to have the following relationship be true:

`A + B - M >= max(X, Y)`

These relationships will mostly hold true via the normal operation of the token linkers on each chain. The only situation that would break it is if you ever

- Mint new ST on Avalanche to any external address. In this case you **need to** air drop an equivalent amount of native ST to the token linker on the subnet.
- Air drop new ST on the subnet. In this case you **need to** mint an equivalent amoount of Avalanche ST to the token linker.

Kickstarting this proccess from scratch can be a bit complicated. This is because of the gas fees that need to be payed to get some native token to the subnet. Let's say that `X<sub>0</sub>` amount of Avalanche ST is already in circulation, and none of it is locked up by the token linker. Then you would undergo the folowing steps to meet the conditions mentioned above:

1. Deploy the `TokenLinkerLockUnlock` as well as the `TokenLinkerProxy` on Avalanche.
2. Air drop a total of `U` ST token to Axelar and yourselves. This `U` needs to be less than `X<sub>0</sub>/2` and more than the amount of ST you controll on Avalanche.
3. This token will be used to
  - Get the `AxelarGateway`, as well as the `ConstAddressDeployer` and `GasService` deployed by Axelar.
  - Get the `TokenLinkerNative` as well as the `TokenLinkerProxy` deployed by you.
  - Pay for gas to facilitate steps 5 and 6.
4. Air drop `X_0-U` token to the token linker on the subnet.
5. Transfer `U` token from Avalanche to the subnet.
6. Give (not air-drop) `U` ST to the token linker on the subnet.
7. You are done! You can now deploy `TokenLinkerMintBurn` and `TokenLinkerProxy` to Ethereum (and any other chains you wish).

The following table shows the values of `X`, `Y`, `A`, `B`, `M`, `A+B` and `X+M` **after** each step.

| step | X | Y | A | B | M | A+B-M | max(X,Y) | A+B-M >= max(X,Y) |
| -------------|-----|-----|-----|-----|-----|-----|-----|-----|-----|
| 1 | X<sub>0</sub> | 0 | 0 | 0 | 0 | 0 | X<sub>0</sub> | no |
| 2 | X<sub>0</sub> | U | 0 | 0 | 0 | 0 | X<sub>0</sub> | no |
| 3 | X<sub>0</sub> | U | 0 | 0 | 0 | 0 | X<sub>0</sub> | no |
| 4 | X<sub>0</sub> | X<sub>0</sub> | 0 | X<sub>0</sub>-U | 0 | X<sub>0</sub>-U | X<sub>0</sub> | no |
| 5 | X<sub>0</sub> | X<sub>0</sub> | U | X<sub>0</sub>-2U | 0 | X<sub>0</sub>-U | X<sub>0</sub> | no |
| 6 | X<sub>0</sub> | X<sub>0</sub> | U | X<sub>0</sub>-U | 0 | X<sub>0</sub> | X<sub>0</sub> | yes |
| 7 | X<sub>0</sub> | X<sub>0</sub> | U | X<sub>0</sub>-U | 0 | X<sub>0</sub> | X<sub>0</sub> | yes |

If you can disable gas fees completely for the start of your blockchain then `U` can be zero and you can skip steps 5 and 6.

### Example Flows

The following (and more) flows can happen now. All of the below assume a user has/receives the tokens unsless otherwise specified.

1. Send `a` ST from Avalanche to the subnet.
2. Send `b` ST from the subnet to Ethereum.
3. Send `c < b` ST from Ethereum to Avalanche.
4. Mint `d` ST to a user on Avalanche **and** air drop `d` ST to the token linker on the subnet.
5. Air drop `e` ST to a user on the subnet **and** mint `e` ST to the token linker on avalanche.

The following table shows the values of `X`, `Y`, `A`, `B`, `M`, `A+B` and `X+M` **after** each step where both neccesairy conditions are satisfied.

| step | X | Y | A | B | M | A+B-M | max(X,Y) | 
| -------------|-----|-----|-----|-----|-----|-----|-----|
| 0 | X<sub>0</sub> | X<sub>0</sub> | U | X<sub>0</sub>-U | 0 | X<sub>0</sub> | X<sub>0</sub> | 
| 1 | X<sub>0</sub> | X<sub>0</sub> | U + a | X<sub>0</sub>-U - a | 0 | X<sub>0</sub> | X<sub>0</sub> |
| 2 | X<sub>0</sub> | X<sub>0</sub> | U + a | X<sub>0</sub>-U - a + b | b | X<sub>0</sub> | X<sub>0</sub> |
| 3 | X<sub>0</sub> | X<sub>0</sub> | U + a - c | X<sub>0</sub>-U - a + b | b - c | X<sub>0</sub> | X<sub>0</sub> |
| 4 | X<sub>0</sub> + d | X<sub>0</sub> + d | U + a - c | X<sub>0</sub>-U - a + b + d | b - c | X<sub>0</sub> + d | X<sub>0</sub> + d|
| 5 | X<sub>0</sub> + d + e| X<sub>0</sub> + d + e | U + a - c + e | X<sub>0</sub>-U - a + b + d | b - c | X<sub>0</sub> + d + e | X<sub>0</sub> + d + e|

If you want a fixed supply token then flows 4 and 5 should never happen.