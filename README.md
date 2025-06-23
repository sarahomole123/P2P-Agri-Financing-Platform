# 🌾 P2P Agri-Financing Platform

A decentralized peer-to-peer agricultural financing platform built on Stacks blockchain that connects investors with farmers, enabling funding of agricultural inputs in exchange for yield-based payouts.

## 🚀 Features

- **👨‍🌾 Farmer Profiles**: Create detailed farmer profiles with experience and farm information
- **💰 Loan Requests**: Farmers can request funding for agricultural inputs
- **🤝 Investment System**: Investors can fund loan requests and earn returns
- **📊 Reputation System**: Track farmer repayment history and reputation scores
- **💸 Automated Payouts**: Yield-based returns distributed automatically to investors
- **🏦 Platform Fees**: Configurable platform fee structure

## 📋 Contract Functions

### Farmer Functions
- `create-farmer-profile` - Register as a farmer with profile details
- `create-loan-request` - Request funding for agricultural needs
- `withdraw-loan-funds` - Withdraw funded loan amount
- `repay-loan` - Repay loan with interest

### Investor Functions
- `invest-in-loan` - Invest STX tokens in farmer loan requests
- `get-investment` - View investment details

### Read-Only Functions
- `get-loan` - Get loan details by ID
- `get-farmer-profile` - View farmer profile information
- `get-investor-profile` - View investor statistics
- `calculate-repayment-amount` - Calculate total repayment amount
- `get-loan-investors` - Get list of loan investors

## 🛠️ Usage Instructions

### Setting up a Farmer Profile

```clarity
(contract-call? .P2P-Agri-Financing-Platform create-farmer-profile 
  "John's Organic Farm" 
  u100  ;; farm size in acres
  u15   ;; years of experience
)
```

### Creating a Loan Request

```clarity
(contract-call? .P2P-Agri-Financing-Platform create-loan-request
  u50000000  ;; 50 STX requested
  u1200      ;; 12% interest rate (basis points)
  u8640      ;; duration in blocks (~60 days)
  "Corn"     ;; crop type
  "Iowa, USA" ;; farm location
)
```

### Investing in a Loan

```clarity
(contract-call? .P2P-Agri-Financing-Platform invest-in-loan
  u1         ;; loan ID
  u10000000  ;; 10 STX investment
)
```

### Withdrawing Loan Funds (Farmer)

```clarity
(contract-call? .P2P-Agri-Financing-Platform withdraw-loan-funds u1)
```

### Repaying a Loan

````clarity
(contract-call? .P2P-Agri-
