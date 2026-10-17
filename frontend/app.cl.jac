# Top-level client app (C): routes for every screen. main.jac renders <App/>.
import from "@jac/runtime" { Router, Routes, Route, Navigate }
import from .ui { load_fonts, no_read_cache, read_cache_off }
import from .theme { FONT_STACK }
import from .phone { Phone }
import from .telemetry { Telemetry }
import from .war_room { WarRoom }
import from .guardian { GuardianScreen }
import from .story { Story }

def:pub App() -> JsxElement {
    if not read_cache_off() {
        no_read_cache();
    }
    load_fonts();
    return <div style={{"fontFamily": FONT_STACK, "minHeight": "100vh"}}>
        <Router>
            <Routes>
                <Route path="/" element={<Navigate to="/war-room" replace={True} />} />
                <Route path="/phone" element={<Phone />} />
                <Route path="/telemetry" element={<Telemetry />} />
                <Route path="/war-room" element={<WarRoom />} />
                <Route path="/guardian" element={<GuardianScreen />} />
                <Route path="/story" element={<Story />} />
                <Route path="*" element={<Navigate to="/war-room" replace={True} />} />
            </Routes>
        </Router>
    </div>;
}
