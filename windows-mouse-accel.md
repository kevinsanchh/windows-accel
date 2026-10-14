Mathematical Architecture of Windows Pointer Ballistics and Cross-Platform Implementation in LinearMouseExecutive Summary and Ballistic Design PhilosophyThe mouse acceleration algorithm implemented in Microsoft Windows—exposed in the user interface as Enhance pointer precision (EPP) and governed at the kernel level by win32k.sys and win32kbase.sys—is a piecewise linear velocity transfer function designed to resolve the fundamental human-computer interaction trade-off between fine pixel-level targeting and rapid full-screen traversal. Originally architected by Steven Bathiche for Windows XP in 2002 under the formal designation Pointer Ballistics, the algorithm replaced legacy step-threshold multipliers (MouseThreshold1 and MouseThreshold2) with a continuous, radially symmetric lookup table stored in the Windows Registry keys SmoothMouseXCurve and SmoothMouseYCurve.Replicating the exact Windows mouse behavior within a fork of LinearMouse on macOS requires resolving two fundamental architectural divergences between the operating systems. Whereas macOS natively relies on a single exponential acceleration curve—or a device-level parametric table managed by IOHIDFamily—coupled with independent resolution scaling (HIDPointerResolution), Windows evaluates the Euclidean vector magnitude of raw sensor counts ("mickeys"), transforms that magnitude through a 5-point composite transfer curve, scales the output by display density (DPI) and sensitivity factors, and accumulates fractional pixel remainders with directional reset logic. Furthermore, LinearMouse natively modifies pointer speed and acceleration by writing device properties to the macOS HID stack via PointerKit rather than intercepting and mutating cursor movement deltas in its CGEventTap pipeline. Consequently, an exact 1:1 behavioral port requires disabling native macOS acceleration (com.apple.mouse.linear = 1) and introducing a stateful EventTransformer in LinearMouse that intercepts raw CGEvent mouse movement packets and applies the complete Windows win32k mathematical pipeline.The Mathematical Formulation of Windows Mouse AccelerationPhysical-to-Virtual Coordinate Mapping and the 3.5 DivisorTo assign physical meaning to the pointer transfer function, Microsoft formulated the underlying ballistic curve as a mapping from physical mouse velocity ($V_{\text{mouse}}$, measured in inches per second on the desk surface) on the horizontal axis to physical pointer velocity ($V_{\text{pointer}}$, measured in inches per second on the display) on the vertical axis. From basic kinematics, the theoretical physical velocity of a mouse reporting raw movement counts ($\text{Mickeys}$) over a bus polling interval is defined by:$$V_{\text{mouse}} = \text{Mickeys} \times \frac{R_{\text{mouse}}}{\text{DPI}_{\text{mouse}}}$$where $R_{\text{mouse}}$ represents the USB/PS2 polling rate (MouseBusUpdateRate in Hz) and $\text{DPI}_{\text{mouse}}$ represents the hardware sensor resolution (MouseResolution in counts per inch). Similarly, the theoretical physical velocity of the on-screen cursor moving $\text{Pixels}_{\text{update}}$ during that same mouse bus update interval is given by:$$V_{\text{pointer}} = \text{Pixels}_{\text{update}} \times \frac{R_{\text{mouse}}}{\text{DPI}_{\text{screen}}}$$where $\text{DPI}_{\text{screen}}$ (ScreenResolution) is the logical display density in dots per inch (defaulting to $96\text{ DPI}$ at $100\%$ Windows display scaling).However, when the Windows XP kernel team implemented this specification inside win32k.sys, the operating system lacked a standardized mechanism to query hardware DPI or dynamic USB polling rates from generic HID mice. To convert incoming raw sensor counts into the registry curve's horizontal lookup coordinate ($X$), win32k.sys substituted a hardcoded constant divisor of $3.5$ (approximating $\approx 0.285714$ inches per second per count, derived from baseline hardware assumptions of a $400\text{ DPI}$ sensor and a $125\text{ Hz}$ USB polling rate):$$X_{\text{lookup}} = \frac{M}{3.5}$$where $M$ is the 2D Euclidean magnitude of raw mouse counts received during the current interrupt or polling interval. Because $3.5$ is hardcoded across all versions of Windows from XP through Windows 11, the input coordinate $X_{\text{lookup}}$ is strictly a linear scaling of raw counts per poll rather than true time-normalized physical velocity.Evolution of the OS Scaling Equation: XP/Vista Inversion to Windows 10/11Once win32k.sys evaluates the transfer function $Y = f(X_{\text{lookup}})$ from the registry curve, it must convert the resulting $Y$ value (representing $V_{\text{pointer}}$) into actual on-screen pixel displacement ($\text{Pixels}_{\text{update}}$). Across Windows history, this conversion underwent three distinct mathematical iterations due to an initial design and implementation bug in Windows XP and Vista.In the 2002 Pointer Ballistics for Windows XP specification, Microsoft mistakenly substituted the monitor refresh rate ($R_{\text{screen}}$, ScreenUpdateRate) for the mouse polling rate ($R_{\text{mouse}}$, MouseBusUpdateRate). Worse still, when solving the documented equation for $\text{Pixels}_{\text{update}}$ in the win32k.sys C implementation, the developers inverted the numerator and denominator (ScreenUpdateRate and ScreenResolution). This created the notorious "out-of-sync and upside-down" behavior in Windows XP and Vista, where increasing the monitor refresh rate (e.g., from $60\text{ Hz}$ to $144\text{ Hz}$) erroneously accelerated the cursor, while increasing display DPI scaling (e.g., from $96\text{ DPI}$ to $144\text{ DPI}$) erroneously slowed the cursor down.In Windows 7, Microsoft eliminated the monitor refresh rate dependency and corrected the inverted DPI fraction, replacing $\frac{R_{\text{screen}}}{\text{DPI}_{\text{screen}}}$ with $\frac{\text{DPI}_{\text{screen}}}{150}$ while simultaneously scaling down the default registry values in SmoothMouseYCurve by a factor of $1.28$. However, using $150$ in the denominator caused Windows 7 pointer movement at $96\text{ DPI}$ to be $2.4\%$ slower than Windows XP at $60\text{ Hz}$ ($\frac{120}{150} \times 1.28 = 1.024$). In Windows 8, 8.1, 10, and 11, Microsoft replaced the constant $150$ with $120$, restoring exact mathematical parity with the original Windows XP $60\text{ Hz}$ / $96\text{ DPI}$ response curve.Formulation / OS GenerationPointer-to-Pixel Conversion Equation (Pixelsupdate\text{Pixels}_{\text{update}}Pixelsupdate​)Registry YYY-Curve Construction Equation (SmoothMouseYCurve\text{SmoothMouseYCurve}SmoothMouseYCurve)Normalization Constant (CnormC_{\text{norm}}Cnorm​ at 96 DPI96\text{ DPI}96 DPI, 60 Hz60\text{ Hz}60 Hz)Behavioral Impact of System Display SettingsTheoretical Ideal$V_{\text{pointer}} \times \left(\frac{\text{DPI}_{\text{screen}}}{R_{\text{mouse}}}\right)$$\text{Gain}_{\text{px}} \times M \times \left(\frac{R_{\text{mouse}}}{\text{DPI}_{\text{screen}}}\right)$Variable ($3.5 \times \frac{R_{\text{mouse}}}{\text{DPI}_{\text{screen}}}$)Independent of monitor refresh rate; scales proportionally with display DPI.Documented Whitepaper (2002)$V_{\text{pointer}} \times \left(\frac{\text{DPI}_{\text{screen}}}{R_{\text{screen}}}\right)$$\text{Gain}_{\text{px}} \times M \times \left(\frac{R_{\text{screen}}}{\text{DPI}_{\text{screen}}}\right)$$2.1875$Erroneously substitutes monitor refresh rate ($R_{\text{screen}}$) for mouse polling rate ($R_{\text{mouse}}$).Windows XP & Vista (Actual)$V_{\text{pointer}} \times \left(\frac{R_{\text{screen}}}{\text{DPI}_{\text{screen}}}\right)$$\text{Gain}_{\text{px}} \times M \times \left(\frac{\text{DPI}_{\text{screen}}}{R_{\text{screen}}}\right)$$5.6000$ ($3.5 \times \frac{96}{60}$)Higher Hz refresh rate accelerates cursor; higher DPI scaling slows cursor.Windows 7$V_{\text{pointer}} \times \left(\frac{\text{DPI}_{\text{screen}}}{150}\right)$$\text{Gain}_{\text{px}} \times M \times \left(\frac{150}{\text{DPI}_{\text{screen}}}\right)$$5.46875$ ($3.5 \times \frac{150}{96}$)Refresh-rate independent; proper DPI scaling; $2.4\%$ slower than XP $60\text{ Hz}$ baseline.Windows 8, 8.1, 10, & 11$V_{\text{pointer}} \times \left(\frac{\text{DPI}_{\text{screen}}}{120}\right)$$\text{Gain}_{\text{px}} \times M \times \left(\frac{120}{\text{DPI}_{\text{screen}}}\right)$$4.3750$ ($3.5 \times \frac{120}{96}$)Refresh-rate independent; proper DPI scaling; exact match to XP $60\text{ Hz}$ curve.Binary Structure and Decoding of SmoothMouseXCurve and SmoothMouseYCurveThe 5 inflection points of the Windows ballistic curve are stored in HKEY_CURRENT_USER\Control Panel\Mouse under the binary registry values SmoothMouseXCurve and SmoothMouseYCurve. Each value is a 40-byte REG_BINARY payload consisting of five 8-byte (64-bit QWORD) blocks. Within each 8-byte block, only the first 4 bytes contain active data, formatted as a 32-bit unsigned 16.16 fixed-point number in little-endian byte order (b0, b1, b2, b3), while the trailing 4 bytes (b4, b5, b6, b7) are zero-padded (00,00,00,00).In this little-endian 16.16 representation, bytes b0 and b1 encode the 16-bit fractional component, and bytes b2 and b3 encode the 16-bit integer component. Converting any 8-byte registry line into its exact floating-point value ($V$) follows the formula:$$V = \frac{\text{uint32\_le}(b_0, b_1, b_2, b_3)}{65536.0} = \left(b_2 + 256 \cdot b_3\right) + \frac{b_0 + 256 \cdot b_1}{65536.0}$$Decoding the default Windows 10/11 and Windows XP/Vista registry blobs yields the exact inflection coordinates and secant gain ratios ($Y_i / X_i$) detailed in the table below.Inflection Point (iii)SmoothMouseXCurve Hex (All Windows Versions)Decoded XiX_iXi​ (VmouseV_{\text{mouse}}Vmouse​)Input Mickeys (Mi=3.5XiM_i = 3.5 X_iMi​=3.5Xi​)SmoothMouseYCurve Hex (Win 7 / 8 / 10 / 11)Decoded YiY_iYi​ (Win 7–11)Decoded YiXPY_i^{\text{XP}}YiXP​ (XP / Vista)Raw Ratio (Yi/XiY_i / X_iYi​/Xi​, Win 7–11)Effective Gain (px/mickey\text{px/mickey}px/mickey at 96 DPI96\text{ DPI}96 DPI, Win 10/11)Point 000,00,00,00,00,00,00,00$0.00000000$$0.000000$00,00,00,00,00,00,00,00$0.00000000$$0.000000$$0.000000$$0.568902$ (limit as $M \to 0^+$)Point 115,6e,00,00,00,00,00,00$0.43000793$$1.505028$fd,11,01,00,00,00,00,00$1.07026672$$1.369995$$2.488946$$0.568902$[cite: 7, 20, 21, 22, 23]Point 200,40,01,00,00,00,00,00$1.25000000$$4.375000$00,24,04,00,00,00,00,00$4.14062500$$5.300003$$3.312500$$0.757143$[cite: 7, 13, 20, 21]Point 329,dc,03,00,00,00,00,00$3.86000061$$13.510002$00,fc,12,00,00,00,00,00$18.98437500$$24.300003$$4.918231$$1.124167$[cite: 7, 20, 21, 22]Point 400,00,28,00,00,00,00,00$40.00000000$$140.000000$00,c0,bb,01,00,00,00,00$443.75000000$$568.000000$$11.093750$$2.535714$[cite: 7, 20, 21]Across all four non-zero inflection points, the ratio of the Windows XP/Vista coordinate $Y_i^{\text{XP}}$ to the Windows 7/8/10/11 coordinate $Y_i$ is invariant at $1.28$ ($568.0 / 443.75 = 1.28$, $24.3 / 18.984375 = 1.28$, $5.3 / 4.140625 = 1.28$). Because the normalization constant in Windows XP at $96\text{ DPI}$ and $60\text{ Hz}$ is $C_{\text{norm}}^{\text{XP}} = 3.5 \times \frac{96}{60} = 5.6$ and the normalization constant in Windows 8/10/11 at $96\text{ DPI}$ is $C_{\text{norm}}^{\text{Win10}} = 3.5 \times \frac{120}{96} = 4.375$, their ratio is $\frac{5.6}{4.375} = 1.28$. Consequently, dividing $Y_i^{\text{XP}}$ by $5.6$ yields the exact same effective pixel gain at every inflection point as dividing $Y_i^{\text{Win10}}$ by $4.375$.Piecewise Linear Interpolation and Hyperbolic Secant GainWhen a mouse movement event occurs with raw integer displacements $(\Delta x, \Delta y)$, Windows does not apply acceleration to each axis independently. Independent axis acceleration biases diagonal movements toward the dominant axis, distorting circular physical motions into rounded squares. Instead, win32k.sys computes the 2D Euclidean vector magnitude $M$ of the incoming movement packet:$$M = \sqrt{\Delta x^2 + \Delta y^2}$$Using $x = \frac{M}{3.5}$, win32k.sys locates the active segment $i \in \{0, 1, 2, 3\}$ in the lookup table such that $X_i \le x \le X_{i+1}$. For any input velocity exceeding the final inflection point ($x > X_4 = 40.0$, or $M > 140\text{ mickeys}$), Windows linearly extrapolates outward along the fourth segment ($i = 3$, defined by $(X_3, Y_3)$ and $(X_4, Y_4)$).Within segment $i$, the transfer function $Y(x)$ is evaluated via linear interpolation between $(X_i, Y_i)$ and $(X_{i+1}, Y_{i+1})$:$$Y(x) = Y_i + m_i \left(x - X_i\right), \quad \text{where } m_i = \frac{Y_{i+1} - Y_i}{X_{i+1} - X_i} \quad \text{and } b_i = Y_i - m_i X_i$$Because $Y(x) = m_i x + b_i$ represents the output velocity magnitude $V_{\text{pointer}}$, the scalar acceleration multiplier applied to both $\Delta x$ and $\Delta y$ is proportional to the secant slope $\frac{Y(x)}{x}$ from the origin $(0,0)$ to the point $(x, Y(x))$ on the curve:$$\frac{Y(x)}{x} = m_i + \frac{b_i}{x} = m_i + \frac{3.5 \, b_i}{M}$$This mathematical structure explains why the Windows acceleration curve appears linear in one domain yet curved in another. In velocity space ($M \mapsto \text{Pixels}_{\text{out}}$), the Windows transfer function is strictly piecewise linear, consisting of four connected line segments with progressively steeper marginal slopes ($\tilde{m}_0 = 0.5689$, $\tilde{m}_1 = 0.8559$, $\tilde{m}_2 = 1.2999$, and $\tilde{m}_3 = 2.6865\text{ pixels/mickey}$ at $96\text{ DPI}$ and default $6/11$ sensitivity). Conversely, in sensitivity or gain space ($M \mapsto \text{Gain}_{\text{px}} = \frac{\text{Pixels}_{\text{out}}}{M}$), because the line segments for $i \ge 1$ have negative vertical intercepts ($b_i < 0$) and do not pass through the origin, dividing $Y(x)$ by $x$ yields a piecewise hyperbolic function ($m_i + \frac{b_i}{x}$) across segments $1, 2,$ and $3$, preceded by a constant gain plateau ($\tilde{m}_0 = 0.568902$) on segment $0$ ($0 < M \le 1.505\text{ mickeys}$). If an alternative implementation pre-computes the secant gain ratios $g_i = \frac{Y_i}{X_i}$ at each inflection point and linearly interpolates $g(x)$ between $g_i$ and $g_{i+1}$, the gain curve becomes piecewise linear while the velocity transfer function becomes piecewise quadratic; standard win32k.sys lookup table evaluation interpolates the pre-scaled transfer table values linearly and divides by magnitude, yielding the parameters tabulated below.Segment Index (iii)Input Domain in Curve Units (X=M/3.5X = M / 3.5X=M/3.5)Input Domain in Mickeys (M=Δx2+Δy2M = \sqrt{\Delta x^2 + \Delta y^2}M=Δx2+Δy2​)Curve Marginal Slope (mi=ΔYiΔXim_i = \frac{\Delta Y_i}{\Delta X_i}mi​=ΔXi​ΔYi​​)Curve Intercept (bi=Yi−miXib_i = Y_i - m_i X_ibi​=Yi​−mi​Xi​)Effective Pixel Marginal Slope (m~i=mi4.375\tilde{m}_i = \frac{m_i}{4.375}m~i​=4.375mi​​)Effective Pixel Intercept (b~i=bi1.25\tilde{b}_i = \frac{b_i}{1.25}b~i​=1.25bi​​)Effective Secant Gain Range (Pixels/M\text{Pixels}/MPixels/M at 96 DPI96\text{ DPI}96 DPI)Segment 0$(0.0000, 0.4300]$$(0.000, 1.505]$$2.488946$$0.000000$$0.568902$$0.000000$Constant $0.568902\times$ (Subpixel deceleration)Segment 1$(0.4300, 1.2500]$$(1.505, 4.375]$$3.744376$$-0.539845$$0.855857$$-0.431876$$0.568902\times \to 0.757143\times$ (Precision transition)Segment 2$(1.2500, 3.8600]$$(4.375, 13.510]$$5.687259$$-2.968449$$1.299945$$-2.374759$$0.757143\times \to 1.124167\times$ (Crosses $1.0\times$ at $M = 8.593$)Segment 3 & Extrapolation$(3.8600, \infty)$$(13.510, \infty)$$11.753338$$-26.383517$$2.686477$$-21.106813$$1.124167\times \to 2.535714\times$ at $M=140$ ($\to 2.6865\times$ as $M \to \infty$)Combining the lookup evaluation with display DPI scaling and the user sensitivity slider factor $S_{\text{slider}}$, the complete master equation for the raw floating-point pixel multiplier $G_{\text{total}}(M)$ in modern Windows (Windows 8, 8.1, 10, and 11) is:$$G_{\text{total}}(M) = S_{\text{slider}} \times \left(\frac{\text{DPI}_{\text{screen}}}{120}\right) \times \frac{Y\!\left(\frac{M}{3.5}\right)}{M} = S_{\text{slider}} \times \left(\frac{\text{DPI}_{\text{screen}}}{420}\right) \times \left(m_i + \frac{3.5 \, b_i}{M}\right)$$And the unrounded transformed cursor displacements $(\Delta X_{\text{float}}, \Delta Y_{\text{float}})$ for a single polling interval are simply:$$\Delta X_{\text{float}} = \Delta x \times G_{\text{total}}(M), \qquad \Delta Y_{\text{float}} = \Delta y \times G_{\text{total}}(M)$$Sensitivity Scaling and Subpixel Remainder Accumulation in win32kbase.sysDual-Mode Control Panel Slider Scaling: EPP-Off vs. EPP-OnA critical nuance of the Windows mouse pipeline is that the 11-tick Pointer Speed slider in the Windows Control Panel (MouseSensitivity in HKEY_CURRENT_USER\Control Panel\Mouse, stored as an integer $S \in [1, 20]$) uses two different mathematical scaling functions depending on whether Enhance pointer precision (EPP) is disabled (MouseSpeed = 0) or enabled (MouseSpeed = 1).When EPP is disabled (MouseSpeed = 0), win32kbase.sys invokes the internal function UpdateMouseSensitivity, which converts the integer MouseSensitivity value $S \in [1, 20]$ into a 24.8 fixed-point speed multiplier (uVar1, where $256 = \text{0x100}$ represents a $1.0\times$ 1:1 ratio) using a three-tier piecewise linear formula with slope inflections at $S = 2$ and $S = 10$:$$S_{\text{EPP\_OFF}}(S) = \begin{cases} \dfrac{S}{32} & \text{if } 1 \le S \le 2 \\ \dfrac{S - 2}{8} & \text{if } 3 \le S \le 10 \\ \dfrac{S - 6}{4} & \text{if } 11 \le S \le 20 \end{cases}$$Under this unaccelerated formula, setting the Control Panel slider to the 4th tick ($S = 6$) yields a multiplier of $0.5\times$, setting it to the default 6th middle tick ($S = 10$) yields $1.0\times$, and setting it to the 11th maximum tick ($S = 20$) yields $3.5\times$.Conversely, when EPP is enabled (MouseSpeed = 1), win32k.sys bypasses the three-tier UpdateMouseSensitivity table and instead scales the ballistic lookup table linearly in proportion to MouseSensitivity normalized to $S = 10$:$$S_{\text{EPP\_ON}}(S) = \frac{S}{10}$$Because the EPP-ON multiplier increases at a constant linear rate of $0.1\times$ per registry increment from $0.1\times$ ($S = 1$) to $2.0\times$ ($S = 20$), whereas the EPP-OFF multiplier transitions across three slope regimes ($1/32$ per step for $S \in [1, 2]$, $1/8$ per step for $S \in [2, 10]$, and $1/4$ per step for $S \in [10, 20]$), the two sensitivity curves intersect solely at the default 6th Control Panel tick ($S = 10$, where both equal $1.0\times$). For all slider settings below the midpoint ($1 \le S \le 9$), the EPP-ON scalar is higher than the EPP-OFF scalar—for instance, at the 4th slider tick ($S = 6$), EPP-ON applies a $0.6\times$ scalar rather than $0.5\times$, making tick 6 ($1.0\times$) $66.7\%$ faster than tick 4 with EPP enabled compared to $100\%$ faster with EPP disabled. Conversely, for all settings above the midpoint ($11 \le S \le 20$), the EPP-ON scalar is lower than the EPP-OFF scalar, reaching $2.0\times$ at the 11th slider tick ($S = 20$) rather than $3.5\times$. All 20 registry MouseSensitivity steps—including the intermediate odd integers accessible via direct registry modification—are detailed in the table below.Control Panel Slider Tick (1–11)Registry MouseSensitivity (S∈[1,20])EPP-OFF Multiplier (SEPP_OFF​)EPP-OFF 24.8 Fixed-Point (uVar1)EPP-ON Ballistic Scalar (SEPP_ON​=S/10)Ratio of EPP-ON to EPP-OFF ScalarTick 1 (Slowest)$1$$0.03125$ ($1/32$)0x0008 ($8$)$0.10000$$3.20\times$[cite: 3, 20]Tick 2$2$$0.06250$ ($1/16$)0x0010 ($16$)$0.20000$$3.20\times$[cite: 3, 20](Registry Only)$3$$0.12500$ ($1/8$)0x0020 ($32$)$0.30000$$2.40\times$[cite: 3]Tick 3$4$$0.25000$ ($1/4$)0x0040 ($64$)$0.40000$$1.60\times$[cite: 3, 20](Registry Only)$5$$0.37500$ ($3/8$)0x0060 ($96$)$0.50000$$1.33\times$[cite: 3, 25]Tick 4$6$$0.50000$ ($1/2$)0x0080 ($128$)$0.60000$$1.20\times$[cite: 3, 13, 20](Registry Only)$7$$0.62500$ ($5/8$)0x00A0 ($160$)$0.70000$$1.12\times$[cite: 3]Tick 5$8$$0.75000$ ($3/4$)0x00C0 ($192$)$0.80000$$1.07\times$[cite: 3, 20](Registry Only)$9$$0.87500$ ($7/8$)0x00E0 ($224$)$0.90000$$1.03\times$[cite: 3]Tick 6 (Default)$10$$1.00000$ ($1/1$)0x0100 ($256$)$1.00000$$1.00\times$[cite: 3, 13, 20, 24](Registry Only)$11$$1.25000$ ($5/4$)0x0140 ($320$)$1.10000$$0.88\times$[cite: 3]Tick 7$12$$1.50000$ ($3/2$)0x0180 ($384$)$1.20000$$0.80\times$[cite: 3, 20](Registry Only)$13$$1.75000$ ($7/4$)0x01C0 ($448$)$1.30000$$0.74\times$[cite: 3]Tick 8$14$$2.00000$ ($2/1$)0x0200 ($512$)$1.40000$$0.70\times$[cite: 3, 20](Registry Only)$15$$2.25000$ ($9/4$)0x0240 ($576$)$1.50000$$0.67\times$[cite: 3]Tick 9$16$$2.50000$ ($5/2$)0x0280 ($640$)$1.60000$$0.64\times$[cite: 3, 19, 20](Registry Only)$17$$2.75000$ ($11/4$)0x02C0 ($704$)$1.70000$$0.62\times$[cite: 3]Tick 10$18$$3.00000$ ($3/1$)0x0300 ($768$)$1.80000$$0.60\times$[cite: 3, 19, 20](Registry Only)$19$$3.25000$ ($13/4$)0x0340 ($832$)$1.90000$$0.58\times$[cite: 3]Tick 11 (Fastest)$20$$3.50000$ ($7/2$)0x0380 ($896$)$2.00000$$0.57\times$[cite: 3, 19, 20, 24]Directional Subpixelation and Remainder Reset LogicBecause the first two segments of the Windows acceleration curve scale slow mouse movements by less than $1.0\text{ pixel/mickey}$ (e.g., $1\text{ mickey} \times 0.568902 = 0.568902\text{ pixels}$), naive integer truncation would discard small movements entirely, creating a deadzone where slow micro-adjustments fail to move the cursor. To preserve every count of sensor input while outputting integer pixel coordinates to the window manager, win32k.sys implements a stateful subpixel remainder accumulator (idxRemainder and idyRemainder in 16.16 or 24.8 fixed-point arithmetic).Crucially, reverse-engineering of win32k.sys demonstrates that Windows does not simply accumulate remainders unconditionally. If a user moves the mouse right (accumulating a $+0.85\text{ px}$ remainder) and then reverses direction to the left or stops movement on that axis, retaining the $+0.85\text{ px}$ remainder would oppose and swallow the initial leftward movement. Therefore, for each axis independently, Windows resets the stored remainder to zero whenever the raw sensor count on that axis is zero or reverses sign relative to the previous non-zero packet:$$\text{rem}_{x, t-1}^* = \begin{cases} 0 & \text{if } \Delta x_t = 0 \;\lor\; \text{sgn}(\Delta x_t) \neq \text{sgn}(\Delta x_{t-1}) \\ \text{rem}_{x, t-1} & \text{otherwise} \end{cases}$$$$\text{rem}_{y, t-1}^* = \begin{cases} 0 & \text{if } \Delta y_t = 0 \;\lor\; \text{sgn}(\Delta y_t) \neq \text{sgn}(\Delta y_{t-1}) \\ \text{rem}_{y, t-1} & \text{otherwise} \end{cases}$$Once the directionally validated remainder is retrieved, it is added to the newly scaled floating-point displacement, truncated toward zero (trunc) to yield the integer pixel output $(\Delta X_{\text{out}, t}, \Delta Y_{\text{out}, t})$, and the fractional residue is saved for the next polling cycle:$$T_{x, t} = \Delta x_t \cdot G_{\text{total}}(M_t) + \text{rem}_{x, t-1}^*, \qquad T_{y, t} = \Delta y_t \cdot G_{\text{total}}(M_t) + \text{rem}_{y, t-1}^*$$$$\Delta X_{\text{out}, t} = \operatorname{trunc}(T_{x, t}), \qquad \Delta Y_{\text{out}, t} = \operatorname{trunc}(T_{y, t})$$$$\text{rem}_{x, t} = T_{x, t} - \Delta X_{\text{out}, t}, \qquad \Delta Y_{\text{out}, t} = T_{y, t} - \Delta Y_{\text{out}, t}$$In Windows XP x64 Edition when EPP was disabled, an optimizing compiler register-allocation bug in GetMouseCoord within win32k.sys executed mov r11d, eax two instructions too early during bit-shift division by 256 (sar r11d, 8), causing negative remainders to bias negative axis movement; Windows 7 and later corrected this truncation toward zero.Architectural Blueprint for Forking LinearMouse on macOSStructural Divergence Between Windows win32k and macOS IOHIDFamilyIn its upstream architecture, LinearMouse is structured around three primary Swift subsystems: LinearMouse/Device/ (which wraps PointerKit to read and write IOHIDEventSystemClient / IOHIDServiceClient properties), LinearMouse/EventTap/ (GlobalEventTap.swift, which installs a system-wide Quartz Event Tap via CGEvent.tapCreate), and LinearMouse/EventTransformer/ (EventTransformerManager.swift, which pipes captured CGEvent objects through composable transformers for scrolling, button remapping, and modifier scaling).Currently, LinearMouse does not route pointer movement events (.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged) through EventTransformerManager. Instead, when a user adjusts pointer speed or acceleration in LinearMouse, the app writes scalar parameters directly to macOS's kernel/driver HID layer via PointerKit—modifying HIDPointerResolution for linear speed and HIDMouseAcceleration (or the macOS Sonoma+ native linear toggle com.apple.mouse.linear) for acceleration. Because macOS's native HIDMouseAcceleration evaluates a single exponential curve rather than Windows' 5-point composite ballistic function, tuning LinearMouse's existing configuration values cannot replicate the Windows curve.Evaluating macOS Implementation PathwaysAs analyzed in LinearMouse GitHub Issue #261 ("Matching Windows mouse acceleration curve") and Issue #33, three distinct technical pathways exist for introducing Windows Pointer Ballistics on macOS:Implementation PathwayTarget macOS SubsystemCPU & Latency OverheadCompatibility (macOS 14 Sonoma / 15 Sequoia / 26 Tahoe)Fidelity to Windows win32k.sysEngineering Feasibility in a LinearMouse ForkPathway 1: User-Space CGEventTap Transformer (EventTransformer)GlobalEventTap.swift + EventTransformer + PointerKit (set to linear 1:1)Negligible (~5–15 µs per poll in Swift)High (Works on all external USB/Bluetooth mice when native accel is disabled)Exact 100% (Full control over 2D magnitude, 5-point curve, and directional remainders)Optimal — Directly leverages LinearMouse's existing EventTransformer architecture.Pathway 2: IOHIDTableAcceleration Property InjectionPointerKit writing binary blob to HIDPointerAccelerationTable[cite: 9, 12]Zero user-space CPU (evaluated in IOHIDFamily)Low / Restricted (Apple locked down HIDPointerResolution & table writes on newer macOS 15/26 drivers)Approximate (Uses Apple's parametric table format and internal time-stamped velocity smoothing)Fragile — Undocumented binary plist structure; fails on restricted HID services.Pathway 3: Custom HIDDriverKit System Extension (DEXT)IOUserHIDEventDriver kernel-adjacent DriverKit extensionNear-zero (executes in DriverKit process before WindowServer)High (Official modern Apple driver architecture)Exact 100% (Intercepts raw HID reports directly)Prohibitive — Requires paid Apple Developer DriverKit entitlements and SIP approval.Based on this architectural comparison, implementing a user-space CGEventTap transformer (EventTransformer) combined with macOS native linear mode (Pathway 1) is the optimal engineering strategy for a fork of LinearMouse. To prevent double-acceleration—where macOS would apply its own exponential curve before LinearMouse applies the Windows ballistic curve—the fork must first instruct PointerKit to disable macOS pointer acceleration (disableAcceleration = true, which sets com.apple.mouse.linear = 1 and com.apple.mouse.scaling = 1 on macOS Sonoma, Sequoia, and Tahoe). With macOS operating in 1:1 linear mode, raw integer sensor counts arrive unmodified inside the CGEvent fields .mouseEventDeltaX and .mouseEventDeltaY.Critical macOS WindowServer Nuance: Updating Both Deltas and Cursor LocationWhen implementing pointer acceleration inside a macOS CGEventTap (kCGHIDEventTap), a fundamental architectural behavior of the macOS WindowServer must be addressed. When a physical mouse moves, the macOS HID driver computes the preliminary new screen coordinate (event.location) before passing the CGEvent to user-space kCGHIDEventTap callbacks. Consequently, simply overwriting .mouseEventDeltaX and .mouseEventDeltaY on the CGEvent changes the relative deltas read by games or 3D viewports that lock the cursor (CGAssociateMouseAndMouseCursorPosition(false)), but does not alter the on-screen cursor position (event.location) in standard desktop applications. Conversely, modifying event.location moves the desktop pointer across the screen, but leaves .mouseEventDeltaX and .mouseEventDeltaY unchanged if an application inspects raw delta fields.Therefore, to achieve a seamless replication of the Windows mouse view across both macOS desktop navigation and relative-delta applications, the WindowsPointerBallisticsTransformer must reconstruct the unaccelerated cursor origin prior to the current event:$$\mathbf{P}_{\text{base}} = \mathbf{P}_{\text{event}} - \begin{pmatrix} \Delta x_{\text{raw}} \\ \Delta y_{\text{raw}} \end{pmatrix}$$It must then set the new event.location to $\mathbf{P}_{\text{base}} + (\Delta X_{\text{out}}, \Delta Y_{\text{out}})^T$ clamped to the union of active display bounds, while simultaneously writing $\Delta X_{\text{out}}$ and $\Delta Y_{\text{out}}$ to .mouseEventDeltaX and .mouseEventDeltaY.Reference Swift Implementation for LinearMouse EventTransformerIntegrating Windows Pointer Ballistics into LinearMouse requires two targeted modifications to the codebase. First, in LinearMouse/EventTap/GlobalEventTap.swift, the .mouseMoved, .leftMouseDragged, .rightMouseDragged, and .otherMouseDragged event types must be added to the CGEventMask bitmask alongside the existing scroll wheel and mouse button event types. Second, a new WindowsPointerBallisticsTransformer.swift file must be created in LinearMouse/EventTransformer/ and registered in EventTransformerManager.swift whenever the active device scheme enables Windows acceleration.Below is the complete, self-contained Swift implementation of WindowsPointerBallisticsTransformer, incorporating the exact 16.16 fixed-point registry constants (0x00006E15, 0x000111FD, etc.), the $3.5$ mickey divisor, the Windows 10/11 ($120$) and Windows 7 ($150$) scaling modes, the dual-mode MouseSensitivity slider table, directional subpixel remainder resets, and CGEvent coordinate clamping:Swiftimport AppKit
import CoreGraphics
import Foundation

/// Replicates the exact Windows win32k.sys / win32kbase.sys Pointer Ballistics ("Enhance pointer precision")
/// mathematical pipeline within LinearMouse's EventTransformer architecture.
public final class WindowsPointerBallisticsTransformer: EventTransformer {
    public enum WindowsOSCurvePreset {
        /// Windows 8, 8.1, 10, and 11 Default (Divisor constant = 120; exact match to Windows XP at 60Hz)
        case windows10And11
        /// Windows 7 Default (Divisor constant = 150; ~2.4% slower than Win 10/11 at 96 DPI)
        case windows7
    }

    private struct CurveSegment {
        let xStart: Double
        let xEnd: Double
        let yStart: Double
        let slope: Double
        let intercept: Double
    }

    // Exact 16.16 fixed-point values from HKEY_CURRENT_USER\Control Panel\Mouse\SmoothMouseXCurve
    // Hex: 00000000, 00006E15, 00014000, 0003DC29, 00280000 divided by 65536.0
    private static let defaultXCurve: [Double] = [
        0.0,
        Double(0x0000_6E15) / 65536.0, // 0.4300079345703125 (1.50502777 mickeys)
        Double(0x0001_4000) / 65536.0, // 1.2500000000000000 (4.37500000 mickeys)
        Double(0x0003_DC29) / 65536.0, // 3.8600006103515625 (13.5100021 mickeys)
        Double(0x0028_0000) / 65536.0  // 40.000000000000000 (140.000000 mickeys)
    ]

    // Exact 16.16 fixed-point values from HKEY_CURRENT_USER\Control Panel\Mouse\SmoothMouseYCurve (Win 7/8/10/11)
    // Hex: 00000000, 000111FD, 00042400, 0012FC00, 01BBC000 divided by 65536.0
    private static let defaultYCurve: [Double] = [
        0.0,
        Double(0x0001_11FD) / 65536.0, // 1.0702667236328125
        Double(0x0004_2400) / 65536.0, // 4.1406250000000000
        Double(0x0012_FC00) / 65536.0, // 18.984375000000000
        Double(0x01BB_C000) / 65536.0  // 443.75000000000000
    ]

    private let segments: [CurveSegment]
    private let enhancePointerPrecision: Bool
    private let mouseSensitivity: Int // Windows Registry MouseSensitivity (1...20, default 10 = 6/11 tick)
    private let effectiveScreenDPI: Double // Windows logical DPI (default 96.0 at 100% scale)
    private let osPreset: WindowsOSCurvePreset

    // Stateful subpixel remainder accumulators and sign trackers (win32k.sys directional reset logic)
    private var remainderX: Double = 0.0
    private var remainderY: Double = 0.0
    private var previousSignX: Int = 0
    private var previousSignY: Int = 0

    public init(
        enhancePointerPrecision: Bool = true,
        mouseSensitivity: Int = 10,
        effectiveScreenDPI: Double = 96.0,
        osPreset: WindowsOSCurvePreset = .windows10And11,
        customXCurve: [Double]? = nil,
        customYCurve: [Double]? = nil
    ) {
        self.enhancePointerPrecision = enhancePointerPrecision
        self.mouseSensitivity = max(1, min(20, mouseSensitivity))
        self.effectiveScreenDPI = effectiveScreenDPI
        self.osPreset = osPreset

        let xPoints = (customXCurve?.count == 5) ? customXCurve! : Self.defaultXCurve
        let yPoints = (customYCurve?.count == 5) ? customYCurve! : Self.defaultYCurve

        var builtSegments: [CurveSegment] = []
        builtSegments.reserveCapacity(4)
        for i in 0..<4 {
            let dx = xPoints[i + 1] - xPoints[i]
            let dy = yPoints[i + 1] - yPoints[i]
            let m = (dx > 0) ? (dy / dx) : 0.0
            let b = yPoints[i] - m * xPoints[i]
            builtSegments.append(
                CurveSegment(
                    xStart: xPoints[i],
                    xEnd: xPoints[i + 1],
                    yStart: yPoints[i],
                    slope: m,
                    intercept: b
                )
            )
        }
        self.segments = builtSegments
    }

    /// Computes the sensitivity scalar from Windows Registry MouseSensitivity (1...20).
    private var sensitivityScalar: Double {
        if enhancePointerPrecision {
            // When EPP is ON, win32k scales the curve linearly: 6/11 (S=10) -> 1.0, 4/11 (S=6) -> 0.6, 11/11 (S=20) -> 2.0
            return Double(mouseSensitivity) / 10.0
        } else {
            // Decompiled UpdateMouseSensitivity in win32kbase.sys for EPP OFF
            if mouseSensitivity < 3 {
                return Double(mouseSensitivity) / 32.0
            } else if mouseSensitivity < 11 {
                return Double(mouseSensitivity - 2) / 8.0
            } else {
                return Double(mouseSensitivity - 6) / 4.0
            }
        }
    }

    /// Evaluates the effective pixel gain multiplier G_total(M) for a 2D input magnitude M (in mickeys).
    public func calculateGain(forMagnitude mickeys: Double) -> Double {
        guard mickeys > 0 else { return 0.0 }
        guard enhancePointerPrecision else { return sensitivityScalar }

        // Convert raw mickeys to curve lookup coordinate X = mickeys / 3.5
        let xLookup = mickeys / 3.5

        // Locate active segment (extrapolating along segment 3 if xLookup > X_4)
        let activeSegment: CurveSegment
        if xLookup <= segments[0].xEnd {
            activeSegment = segments[0]
        } else if xLookup <= segments[1].xEnd {
            activeSegment = segments[1]
        } else if xLookup <= segments[2].xEnd {
            activeSegment = segments[2]
        } else {
            activeSegment = segments[3]
        }

        // Evaluate Y = V_pointer(xLookup) and divide by xLookup to obtain secant gain Y/X
        let yValue = activeSegment.yStart + activeSegment.slope * (xLookup - activeSegment.xStart)
        let curveSecantGain = yValue / xLookup

        // Apply OS normalization constant: 3.5 * 120 = 420 for Win 8/10/11, or 3.5 * 150 = 525 for Win 7
        let osConstant: Double = (osPreset == .windows10And11) ? 120.0 : 150.0
        let dpiNormalization = effectiveScreenDPI / (3.5 * osConstant)

        return sensitivityScalar * dpiNormalization * curveSecantGain
    }

    public func transform(_ event: CGEvent) -> CGEvent? {
        let supportedTypes: [CGEventType] = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
        ]
        guard supportedTypes.contains(event.type) else {
            return event
        }

        let rawDX = Int(event.getIntegerValueField(.mouseEventDeltaX))
        let rawDY = Int(event.getIntegerValueField(.mouseEventDeltaY))

        if rawDX == 0 && rawDY == 0 {
            remainderX = 0.0
            remainderY = 0.0
            previousSignX = 0
            previousSignY = 0
            return event
        }

        // Directional remainder reset per win32k.sys: reset axis remainder on zero or sign reversal
        let currentSignX = (rawDX > 0) ? 1 : ((rawDX < 0) ? -1 : 0)
        let currentSignY = (rawDY > 0) ? 1 : ((rawDY < 0) ? -1 : 0)

        if currentSignX == 0 || currentSignX != previousSignX {
            remainderX = 0.0
        }
        if currentSignY == 0 || currentSignY != previousSignY {
            remainderY = 0.0
        }
        previousSignX = currentSignX
        previousSignY = currentSignY

        // 2D Euclidean vector magnitude M = sqrt(dx^2 + dy^2)
        let dxDouble = Double(rawDX)
        let dyDouble = Double(rawDY)
        let magnitude = hypot(dxDouble, dyDouble)

        let gain = calculateGain(forMagnitude: magnitude)

        // Subpixel accumulation and truncation toward zero
        let totalX = dxDouble * gain + remainderX
        let totalY = dyDouble * gain + remainderY

        let outDX = Int64(totalX.rounded(.towardZero))
        let outDY = Int64(totalY.rounded(.towardZero))

        remainderX = totalX - Double(outDX)
        remainderY = totalY - Double(outDY)

        // Update CGEvent delta fields for relative-input consumers
        event.setIntegerValueField(.mouseEventDeltaX, value: outDX)
        event.setIntegerValueField(.mouseEventDeltaY, value: outDY)

        // Reconstruct unaccelerated base coordinate and apply transformed deltas to cursor location
        let currentLoc = event.location
        let baseX = currentLoc.x - CGFloat(rawDX)
        let baseY = currentLoc.y - CGFloat(rawDY)
        let targetPoint = CGPoint(
            x: baseX + CGFloat(outDX),
            y: baseY + CGFloat(outDY)
        )

        event.location = Self.clampToScreens(targetPoint)
        return event
    }

    private static func clampToScreens(_ point: CGPoint) -> CGPoint {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return point }

        // Convert NSScreen Cocoa coordinates to CoreGraphics top-left origin coordinates if needed,
        // or check containment using CGGetDisplaysWithPoint
        var displayID: CGDirectDisplayID = 0
        var count: UInt32 = 0
        if CGGetDisplaysWithPoint(point, 1, &displayID, &count) == .success, count > 0 {
            return point
        }

        // Clamp to the nearest display bounds if outside all screens
        let mainBounds = CGDisplayBounds(CGMainDisplayID())
        let clampedX = min(max(point.x, mainBounds.minX), mainBounds.maxX - 1.0)
        let clampedY = min(max(point.y, mainBounds.minY), mainBounds.maxY - 1.0)
        return CGPoint(x: clampedX, y: clampedY)
    }
}
Calibration, Polling Rate Considerations, and Implementation ConclusionsEnforcing Native Linear Mode in PointerKitWhen deploying this mathematical model inside a fork of LinearMouse on macOS, three second-order system interactions govern how closely the subjective cursor feel matches a target Windows workstation. Foremost among these is disabling native macOS acceleration prior to applying the user-space transformer. In LinearMouse's PointerDevice configuration, the fork must programmatically enforce pointer.disableAcceleration = true (which sets com.apple.mouse.linear = 1 on macOS Sonoma, Sequoia, and Tahoe) and set the baseline tracking speed to 1.0 (com.apple.mouse.scaling = 1) whenever WindowsPointerBallisticsTransformer is active. Setting com.apple.mouse.linear = 1 alongside com.apple.mouse.scaling = 1 delivers raw 1:1 sensor counts equivalent to Windows 6/11 with EPP disabled. Developers should note that while external USB and Bluetooth mice remain fully controllable via this mechanism, Apple restricts low-level HIDPointerResolution modifications on built-in Apple Silicon trackpads (M2 through M4) and Magic Trackpads under macOS Sequoia (15) and Tahoe (26).Polling Rate Dependency vs. Time-Normalized Synchronous ModeBecause Windows win32k.sys hardcodes $X_{\text{lookup}} = \frac{M}{3.5}$ in counts per poll rather than dividing by the elapsed polling interval $\Delta t$ in milliseconds, native Windows mouse acceleration is inherently polling-rate dependent. Moving a mouse at a constant physical velocity on a $1000\text{ Hz}$ mouse ($1\text{ ms}$ poll interval) produces one-eighth as many mickeys per packet as a $125\text{ Hz}$ mouse ($8\text{ ms}$ poll interval), shifting the operating point leftward on SmoothMouseXCurve. If the engineering objective is to replicate the exact behavior of a Windows PC using the same physical mouse at the same USB polling rate and DPI, evaluating raw counts $M = \sqrt{\Delta x^2 + \Delta y^2}$ without $\Delta t$ normalization is mathematically mandatory. Conversely, if a user switches between mice with different polling rates (such as a $125\text{ Hz}$ Bluetooth office mouse and a $1000\text{ Hz}$ 2.4GHz wireless gaming mouse) and desires polling-rate-invariant Windows ballistics—analogous to RawAccel's Natural / Synchronous mode referenced in LinearMouse Issue #261—the input magnitude $M$ can be normalized to a reference polling rate $R_{\text{ref}}$ (such as $125\text{ Hz}$ or $1000\text{ Hz}$) via $M_{\text{norm}} = \frac{M}{\Delta t_{\text{ms}} \cdot (R_{\text{ref}} / 1000)}$ using CGEvent.timestamp deltas.Display Scaling Parity Between Windows DPI and macOS Retina PointsFinally, achieving visual trajectory parity requires aligning Windows display DPI scaling (effectiveScreenDPI) with macOS Retina logical coordinate spaces. On Windows, ScreenResolution defaults to $96\text{ DPI}$ at $100\%$ scale, $120\text{ DPI}$ at $125\%$ scale, and $144\text{ DPI}$ at $150\%$ scale. On macOS, CoreGraphics CGEvent coordinates operate in logical points (where $1\text{ point} = 2\times 2\text{ physical pixels}$ on a $2\times$ HiDPI Retina display), which already abstracts high-density pixel scaling at the window server level. Consequently, setting effectiveScreenDPI = 96.0 in WindowsPointerBallisticsTransformer maps 1 logical point on macOS directly to 1 pixel on a $100\%$-scaled Windows monitor; if replicating a Windows workstation running at $125\%$ or $150\%$ display scaling on an identical monitor, setting effectiveScreenDPI to $96.0 \times \text{Scale}_{\text{Windows}}$ (e.g., $120.0$ or $144.0$) reproduces the exact physical-inch-to-screen-proportion trajectory.