# Personalization Settings Personalization Settings

## Layout
| Lang | Description |
|-|-|
| EN | Layout |
| NL | Indeling |

| Data | Type | Description |
|-|-|-|
| 0 | DWORD | Default / Standaard |
| 1 | DWORD | More pins / Meer vastgemaakte items |
| 2 | DWORD | More recommendations / Meer aanbevelingen |

Default value:
```Registry
[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced]
"Start_Layout"=dword:00000001
```

## Show recently added apps
| Lang | Description |
|-|-|
| EN | Show recently added apps |
| NL | Recent toegevoegde apps weergeven |

| Data | Type | Description |
|-|-|-|
| 0 | DWORD | Disabled |
| 1 | DWORD | Enabled |

Default value:
```Registry
[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Start]
"ShowRecentList"=dword:00000001
```

## Show most used apps
| Lang | Description |
|-|-|
| EN | Show most used apps |
| NL | Meestgebruikte apps weergeven |

| Data | Type | Description |
|-|-|-|
| 0 | DWORD | Disabled | Yes |
| 1 | DWORD | Enabled | No |

Default value:
```Registry
[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Start]
"ShowFrequentList"=dword:00000000
```

## Show recommended files in Start, recent files in File Explorer, and items in Jump Lists
| Lang | Description |
|-|-|
| EN | Show recommended files in Start, recent files in File Explorer, and items in Jump Lists |
| NL | Aanbevolen bestanden in Start, recente bestanden in Verkenner en items in jumplists |

| Data | Type | Description |
|-|-|-|
| 0 | DWORD | Disabled |
| 1 | DWORD | Enabled |

Default value:
```Registry
[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced]
"Start_TrackDocs"=dword:00000001
```

## Show recommendations for tips, shortcuts, new apps , and more
| Lang | Description |
|-|-|
| EN | Show recommendations for tips, shortcuts, new apps , and more |
| NL | Aanbevelingen voor tips, snelkoppelingen, nieuwe apps en meer weergeven |

| Data | Type | Description |
|-|-|-|
| 0 | DWORD | Disabled |
| 1 | DWORD | Enabled |

Default value:
```Registry
[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced]
"Start_IrisRecommendations"=dword:00000001
```

## Show account-related notifications
| Lang | Description |
|-|-|
| EN | Show account-related notifications |
| NL | Geef account gerelateerde meldingen weer |

| Data | Type | Description |
|-|-|-|
| 0 | DWORD | Disabled |
| 1 | DWORD | Enabled |

Default value:
```Registry
[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced]
"Start_AccountNotifications"=dword:00000001
```
