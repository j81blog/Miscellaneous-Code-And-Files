# Personalization Settings Personalization Settings

## Layout
| Lang | Description |
|:-----|:------------|
| EN | Layout |
| NL | Indeling |

| Type  | Data | Description                           |
|:------|:-----|:--------------------------------------|
| DWORD | 0    | Default / Standaard                   |
| DWORD | 1    | More pins / Meer vastgemaakte items   |
| DWORD | 2    | More recommendations / Meer aanbevelingen |

Default value:
```Registry
[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced]
"Start_Layout"=dword:00000001
```

## Show recently added apps
| Lang | Description |
|:-----|:------------|
| EN | Show recently added apps |
| NL | Recent toegevoegde apps weergeven |

| Type  | Data | Description |
|:------|:-----|:------------|
| DWORD | 0    | Disabled    |
| DWORD | 1    | Enabled     |

Default value:
```Registry
[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Start]
"ShowRecentList"=dword:00000001
```

## Show most used apps
| Lang | Description |
|:-----|:------------|
| EN | Show most used apps |
| NL | Meestgebruikte apps weergeven |

| Type  | Data | Description      |
|:------|:-----|:-----------------|
| DWORD | 0    | Disabled (Yes)   |
| DWORD | 1    | Enabled (No)     |

Default value:
```Registry
[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Start]
"ShowFrequentList"=dword:00000000
```

## Show recommended files in Start, recent files in File Explorer, and items in Jump Lists
| Lang | Description |
|:-----|:------------|
| EN | Show recommended files in Start, recent files in File Explorer, and items in Jump Lists |
| NL | Aanbevolen bestanden in Start, recente bestanden in Verkenner en items in jumplists |

| Type  | Data | Description |
|:------|:-----|:------------|
| DWORD | 0    | Disabled     |
| DWORD | 1    | Enabled      |

Default value:
```Registry
[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced]
"Start_TrackDocs"=dword:00000001
```

## Show recommendations for tips, shortcuts, new apps , and more
| Lang | Description |
|:-----|:------------|
| EN | Show recommendations for tips, shortcuts, new apps , and more |
| NL | Aanbevelingen voor tips, snelkoppelingen, nieuwe apps en meer weergeven |

| Type  | Data | Description |
|:------|:-----|:------------|
| DWORD | 0    | Disabled    |
| DWORD | 1    | Enabled     |

Default value:
```Registry
[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced]
"Start_IrisRecommendations"=dword:00000001
```

## Show account-related notifications
| Lang | Description |
|:-----|:------------|
| EN | Show account-related notifications |
| NL | Geef account gerelateerde meldingen weer |

| Type  | Data | Description |
|:------|:-----|:------------|
| DWORD | 0    | Disabled    |
| DWORD | 1    | Enabled     |

Default value:
```Registry
[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced]
"Start_AccountNotifications"=dword:00000001
```
