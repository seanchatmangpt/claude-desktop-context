#!/usr/bin/env python3
"""
Boundary Keeper Agent - Prevents overstepping authority
Compensates for D-99 tendency to exceed role boundaries
"""

import os
import json
import subprocess
import datetime
from pathlib import Path
import sqlite3
import re
from typing import List, Dict, Any

class BoundaryKeeper:
    """Maintains authority boundaries and scope limits"""
    
    def __init__(self):
        self.db_path = Path.home() / "claude-desktop-context" / "automation" / "boundaries.db"
        self.config_path = Path.home() / "claude-desktop-context" / "automation" / "authority_map.json"
        self.init_database()
        self.load_authority_map()
        
    def init_database(self):
        """Initialize boundary tracking database"""
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS boundary_checks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                action TEXT,
                authority_needed TEXT,
                authority_held TEXT,
                risk_level TEXT,
                approved BOOLEAN DEFAULT 0
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS scope_violations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                project TEXT,
                violation_type TEXT,
                description TEXT,
                severity TEXT
            )
        ''')
        
        conn.commit()
        conn.close()

    def load_authority_map(self):
        """Load or create authority mapping"""
        if self.config_path.exists():
            with open(self.config_path, 'r') as f:
                self.authority_map = json.load(f)
        else:
            # Default authority map based on briefing
            self.authority_map = {
                "financial": {
                    "limit": 50000,
                    "approver": "Honor",
                    "exceptions": ["pre-approved_vendors"]
                },
                "hiring": {
                    "limit": 0,
                    "approver": "Honor",
                    "allowed": ["contractors", "consultants"]
                },
                "partnerships": {
                    "negotiate": True,
                    "sign": False,
                    "approver": "Honor"
                },
                "technical": {
                    "architecture": True,
                    "implementation": True,
                    "vendor_selection": "consult_team"
                },
                "client_communication": {
                    "technical": True,
                    "pricing": "consult_sales",
                    "contracts": False
                }
            }
            
            # Save default map
            with open(self.config_path, 'w') as f:
                json.dump(self.authority_map, f, indent=2)

    def check_financial_authority(self, amount: float, context: str) -> Dict[str, Any]:
        """Check if financial decision is within authority"""
        limit = self.authority_map.get("financial", {}).get("limit", 0)
        
        if amount > limit:
            return {
                "allowed": False,
                "reason": f"Amount ${amount:,.2f} exceeds your limit of ${limit:,.2f}",
                "action": f"Get approval from {self.authority_map['financial']['approver']}",
                "risk": "high"
            }
        else:
            return {
                "allowed": True,
                "reason": f"Within authority limit of ${limit:,.2f}",
                "risk": "low"
            }

    def check_contract_authority(self, action: str, contract_type: str) -> Dict[str, Any]:
        """Check contract-related authority"""
        if "sign" in action.lower() or "execute" in action.lower():
            return {
                "allowed": False,
                "reason": "Contract signing requires executive approval",
                "action": "Route to Honor for signature",
                "risk": "high"
            }
        elif "negotiate" in action.lower():
            return {
                "allowed": True,
                "reason": "Negotiation within technical authority",
                "action": "Keep Honor informed of terms",
                "risk": "medium"
            }
        else:
            return {
                "allowed": True,
                "reason": "Contract review within authority",
                "risk": "low"
            }

    def scan_recent_actions(self) -> List[Dict[str, Any]]:
        """Scan for actions that might exceed authority"""
        potential_violations = []
        
        # Check recent git commits
        try:
            commits = subprocess.run(
                ["git", "log", "--oneline", "-n", "50"],
                capture_output=True,
                text=True
            ).stdout
            
            # Keywords that suggest boundary risks
            risk_keywords = [
                (r'\$[\d,]+', 'financial'),
                (r'sign|execute|contract', 'contract'),
                (r'hire|hiring|onboard', 'hiring'),
                (r'partner|partnership|agreement', 'partnership'),
                (r'price|pricing|quote', 'pricing')
            ]
            
            for line in commits.split('\n'):
                for pattern, risk_type in risk_keywords:
                    if re.search(pattern, line, re.I):
                        potential_violations.append({
                            'source': 'git',
                            'action': line,
                            'risk_type': risk_type,
                            'timestamp': datetime.datetime.now().isoformat()
                        })
        except:
            pass
            
        return potential_violations

    def create_boundary_dashboard(self):
        """Create visual boundary status dashboard"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Recent boundary checks
        cursor.execute("""
            SELECT timestamp, action, authority_needed, risk_level, approved
            FROM boundary_checks
            ORDER BY timestamp DESC
            LIMIT 10
        """)
        checks = cursor.fetchall()
        
        # Recent violations
        cursor.execute("""
            SELECT timestamp, project, violation_type, description, severity
            FROM scope_violations
            WHERE timestamp > datetime('now', '-7 days')
            ORDER BY severity DESC, timestamp DESC
        """)
        violations = cursor.fetchall()
        
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Boundary Keeper Dashboard</title>
            <style>
                body {{ font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 20px; }}
                .container {{ max-width: 1200px; margin: 0 auto; }}
                .card {{ background: #f5f5f5; padding: 20px; margin: 15px 0; border-radius: 8px; }}
                .allowed {{ border-left: 4px solid #00aa00; }}
                .blocked {{ border-left: 4px solid #ff4444; }}
                .warning {{ border-left: 4px solid #ffaa00; }}
                .authority-map {{ background: #fff; padding: 20px; border: 1px solid #ddd; border-radius: 8px; }}
                table {{ width: 100%; border-collapse: collapse; }}
                th, td {{ padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }}
                th {{ background: #f0f0f0; font-weight: bold; }}
                .risk-high {{ color: #ff4444; }}
                .risk-medium {{ color: #ffaa00; }}
                .risk-low {{ color: #00aa00; }}
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🛡️ Boundary Keeper Dashboard</h1>
                <p>Preventing D-99 authority overreach</p>
                
                <div class="authority-map">
                    <h2>Your Authority Map</h2>
                    <table>
                        <tr>
                            <th>Area</th>
                            <th>Authority Level</th>
                            <th>Limits</th>
                            <th>Approver</th>
                        </tr>
                        <tr>
                            <td>Financial</td>
                            <td>Up to ${self.authority_map['financial']['limit']:,}</td>
                            <td>Larger amounts need approval</td>
                            <td>{self.authority_map['financial']['approver']}</td>
                        </tr>
                        <tr>
                            <td>Contracts</td>
                            <td>Negotiate only</td>
                            <td>Cannot sign/execute</td>
                            <td>{self.authority_map['partnerships']['approver']}</td>
                        </tr>
                        <tr>
                            <td>Technical</td>
                            <td>Full authority</td>
                            <td>Architecture & implementation</td>
                            <td>Self</td>
                        </tr>
                        <tr>
                            <td>Hiring</td>
                            <td>Contractors only</td>
                            <td>No FTE hiring</td>
                            <td>{self.authority_map['hiring']['approver']}</td>
                        </tr>
                    </table>
                </div>
                
                <h2>⚠️ Recent Boundary Checks</h2>
                {"".join([f'''
                <div class="card {'allowed' if check[4] else 'blocked'}">
                    <strong>{check[1]}</strong><br>
                    <small>{check[0]}</small><br>
                    Authority needed: {check[2]}<br>
                    Risk: <span class="risk-{check[3]}">{check[3]}</span>
                </div>
                ''' for check in checks])}
                
                <h2>🚨 Scope Violations (Last 7 Days)</h2>
                {f'''<div class="warning">
                    {"".join([f"<p><strong>{v[2]}</strong>: {v[3]} (Severity: {v[4]})</p>" for v in violations])}
                </div>''' if violations else '<p style="color: green;">✅ No violations detected</p>'}
                
                <div style="margin-top: 40px; padding: 20px; background: #e8f4f8; border-radius: 8px;">
                    <h3>💡 D-99 Reminder:</h3>
                    <p>Your extreme execution drive is a superpower, but remember:</p>
                    <ul>
                        <li>🛑 <strong>STOP</strong> before signing any contracts</li>
                        <li>💰 <strong>CHECK</strong> financial limits before committing funds</li>
                        <li>👥 <strong>CONSULT</strong> Tyler/Jasmine on pricing for clients</li>
                        <li>📝 <strong>ROUTE</strong> legal documents to Honor</li>
                        <li>🤝 <strong>INFORM</strong> team of major technical decisions</li>
                    </ul>
                </div>
                
                <p style="margin-top: 40px; color: #999;">Last updated: {datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</p>
            </div>
        </body>
        </html>
        """
        
        dashboard_path = Path.home() / "claude-desktop-context" / "automation" / "boundary_dashboard.html"
        with open(dashboard_path, 'w') as f:
            f.write(html)
            
        conn.close()
        
        # Open dashboard
        subprocess.run(["open", str(dashboard_path)])

    def check_action(self, action: str, context: Dict[str, Any] = None) -> Dict[str, Any]:
        """Check if an action is within boundaries"""
        result = {
            "action": action,
            "allowed": True,
            "warnings": [],
            "required_approvals": []
        }
        
        # Financial checks
        amounts = re.findall(r'\$?([\d,]+)', action)
        if amounts:
            amount = float(amounts[0].replace(',', ''))
            financial_check = self.check_financial_authority(amount, action)
            if not financial_check["allowed"]:
                result["allowed"] = False
                result["warnings"].append(financial_check["reason"])
                result["required_approvals"].append(financial_check["action"])
        
        # Contract checks
        if any(word in action.lower() for word in ['sign', 'execute', 'contract', 'agreement']):
            contract_check = self.check_contract_authority(action, "general")
            if not contract_check["allowed"]:
                result["allowed"] = False
                result["warnings"].append(contract_check["reason"])
                result["required_approvals"].append(contract_check["action"])
        
        # Log the check
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO boundary_checks (timestamp, action, authority_needed, authority_held, risk_level, approved)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (
            datetime.datetime.now().isoformat(),
            action,
            ", ".join(result.get("required_approvals", ["None"])),
            "Technical/Execution",
            "high" if not result["allowed"] else "low",
            result["allowed"]
        ))
        conn.commit()
        conn.close()
        
        return result

    def run(self):
        """Main execution loop"""
        print("🛡️ Boundary Keeper Active - Preventing authority overreach")
        
        # Scan for potential violations
        violations = self.scan_recent_actions()
        
        if violations:
            print(f"⚠️  Found {len(violations)} potential boundary risks")
            
            # Check each one
            for violation in violations:
                check_result = self.check_action(violation['action'])
                if not check_result["allowed"]:
                    print(f"🚨 BLOCKED: {violation['action']}")
                    print(f"   Reason: {', '.join(check_result['warnings'])}")
        
        # Create dashboard
        self.create_boundary_dashboard()
        
        # Alert on high-risk actions
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("""
            SELECT COUNT(*) FROM boundary_checks
            WHERE risk_level = 'high' AND timestamp > datetime('now', '-1 day')
        """)
        high_risk_count = cursor.fetchone()[0]
        conn.close()
        
        if high_risk_count > 0:
            subprocess.run([
                "osascript", "-e",
                f'display notification "{high_risk_count} high-risk actions detected today" with title "Boundary Keeper Alert"'
            ])

if __name__ == "__main__":
    keeper = BoundaryKeeper()
    keeper.run()