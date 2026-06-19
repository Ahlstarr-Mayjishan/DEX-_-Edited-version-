using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;
using System.Diagnostics;
using System.Drawing.Drawing2D;
using System.Net.Http;
using System.Runtime.InteropServices;

namespace DEXHelperApp;

public sealed class MainForm : Form
{
    private const string DashboardUrl = "http://localhost:8080/";
    private readonly Panel titleBar = new();
    private readonly Label titleLabel = new();
    private readonly Button minimizeButton = new();
    private readonly Button maximizeButton = new();
    private readonly Button closeButton = new();
    private readonly WebView2 webView = new();
    private readonly Label loadingLabel = new();
    private readonly Label statusLabel = new();
    private Process? helperProcess;
    private bool ownsHelper;

    public MainForm()
    {
        Text = "DEX++ Helper";
        MinimumSize = new Size(860, 580);
        Size = new Size(1180, 760);
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(10, 14, 19);
        ForeColor = Color.FromArgb(240, 244, 247);
        Font = new Font("Segoe UI", 9F);
        FormBorderStyle = FormBorderStyle.None;
        DoubleBuffered = true;

        BuildChrome();
        BuildContent();
        Resize += (_, _) => maximizeButton.Invalidate();
    }

    protected override async void OnShown(EventArgs e)
    {
        base.OnShown(e);
        try
        {
            await EnsureHelperAsync();
            await InitializeWebViewAsync();
        }
        catch (Exception exception)
        {
            loadingLabel.Text = exception.Message;
            File.AppendAllText(
                Path.Combine(AppContext.BaseDirectory, "app_error.log"),
                DateTime.Now.ToString("u") + Environment.NewLine + exception + Environment.NewLine + Environment.NewLine);
        }
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        base.OnFormClosed(e);
        if (ownsHelper && helperProcess is { HasExited: false })
        {
            try { helperProcess.Kill(entireProcessTree: true); } catch { }
        }
    }

    protected override void WndProc(ref Message message)
    {
        const int wmNchittest = 0x0084;
        const int htClient = 1;
        const int htLeft = 10;
        const int htRight = 11;
        const int htTop = 12;
        const int htTopLeft = 13;
        const int htTopRight = 14;
        const int htBottom = 15;
        const int htBottomLeft = 16;
        const int htBottomRight = 17;

        base.WndProc(ref message);
        if (message.Msg != wmNchittest || (int)message.Result != htClient) return;

        Point cursor = PointToClient(Cursor.Position);
        int grip = 7;
        bool left = cursor.X <= grip;
        bool right = cursor.X >= ClientSize.Width - grip;
        bool top = cursor.Y <= grip;
        bool bottom = cursor.Y >= ClientSize.Height - grip;

        if (left && top) message.Result = htTopLeft;
        else if (right && top) message.Result = htTopRight;
        else if (left && bottom) message.Result = htBottomLeft;
        else if (right && bottom) message.Result = htBottomRight;
        else if (left) message.Result = htLeft;
        else if (right) message.Result = htRight;
        else if (top) message.Result = htTop;
        else if (bottom) message.Result = htBottom;
    }

    private void BuildChrome()
    {
        titleBar.Dock = DockStyle.Top;
        titleBar.Height = 44;
        titleBar.BackColor = Color.FromArgb(12, 17, 23);
        titleBar.MouseDown += (_, e) =>
        {
            if (e.Button == MouseButtons.Left)
            {
                ReleaseCapture();
                SendMessage(Handle, 0xA1, 0x2, 0);
            }
        };
        titleBar.DoubleClick += (_, _) => ToggleMaximize();
        Controls.Add(titleBar);

        titleLabel.AutoSize = false;
        titleLabel.Dock = DockStyle.Left;
        titleLabel.Width = 260;
        titleLabel.Text = "DEX++  /  HELPER";
        titleLabel.TextAlign = ContentAlignment.MiddleLeft;
        titleLabel.Padding = new Padding(18, 0, 0, 1);
        titleLabel.Font = new Font("Segoe UI Semibold", 12F, FontStyle.Regular);
        titleLabel.ForeColor = Color.FromArgb(236, 241, 245);
        titleBar.Controls.Add(titleLabel);

        AddChromeButton(closeButton, "close", (_, _) => Close());
        AddChromeButton(maximizeButton, "maximize", (_, _) => ToggleMaximize());
        AddChromeButton(minimizeButton, "minimize", (_, _) => WindowState = FormWindowState.Minimized);
    }

    private void AddChromeButton(Button button, string glyph, EventHandler click)
    {
        button.Dock = DockStyle.Right;
        button.Width = 48;
        button.Text = "";
        button.Tag = glyph;
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderSize = 0;
        button.BackColor = titleBar.BackColor;
        button.ForeColor = Color.FromArgb(152, 166, 178);
        button.Click += click;
        button.Paint += PaintChromeButton;
        button.MouseEnter += (_, _) => button.BackColor = glyph == "close" ? Color.FromArgb(115, 38, 45) : Color.FromArgb(27, 36, 45);
        button.MouseLeave += (_, _) => button.BackColor = titleBar.BackColor;
        titleBar.Controls.Add(button);
    }

    private static void PaintChromeButton(object? sender, PaintEventArgs e)
    {
        if (sender is not Button button) return;
        string glyph = button.Tag as string ?? "";
        using Pen pen = new(button.ForeColor, 1.6f)
        {
            StartCap = LineCap.Round,
            EndCap = LineCap.Round,
        };
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;

        int cx = button.Width / 2;
        int cy = button.Height / 2;
        if (glyph == "minimize")
        {
            e.Graphics.DrawLine(pen, cx - 9, cy + 4, cx + 9, cy + 4);
        }
        else if (glyph == "maximize")
        {
            if (button.FindForm()?.WindowState == FormWindowState.Maximized)
            {
                e.Graphics.DrawRectangle(pen, new Rectangle(cx - 5, cy - 8, 12, 12));
                e.Graphics.DrawRectangle(pen, new Rectangle(cx - 8, cy - 5, 12, 12));
            }
            else
            {
                e.Graphics.DrawRectangle(pen, new Rectangle(cx - 7, cy - 7, 14, 14));
            }
        }
        else if (glyph == "close")
        {
            e.Graphics.DrawLine(pen, cx - 7, cy - 7, cx + 7, cy + 7);
            e.Graphics.DrawLine(pen, cx + 7, cy - 7, cx - 7, cy + 7);
        }
    }

    private void BuildContent()
    {
        loadingLabel.Dock = DockStyle.Fill;
        loadingLabel.Text = "Starting DEX++ Helper...";
        loadingLabel.TextAlign = ContentAlignment.MiddleCenter;
        loadingLabel.Font = new Font("Segoe UI Semibold", 13F);
        loadingLabel.ForeColor = Color.FromArgb(143, 160, 177);
        Controls.Add(loadingLabel);

        statusLabel.Dock = DockStyle.Bottom;
        statusLabel.Height = 28;
        statusLabel.Text = "Helper: starting  |  Script: checking";
        statusLabel.TextAlign = ContentAlignment.MiddleLeft;
        statusLabel.Padding = new Padding(14, 0, 0, 0);
        statusLabel.BackColor = Color.FromArgb(12, 17, 23);
        statusLabel.ForeColor = Color.FromArgb(143, 160, 177);
        Controls.Add(statusLabel);

        webView.Dock = DockStyle.Fill;
        webView.Visible = false;
        Controls.Add(webView);
        webView.BringToFront();
        statusLabel.BringToFront();
        titleBar.BringToFront();
    }

    private async Task EnsureHelperAsync()
    {
        if (await IsHelperOnlineAsync())
        {
            await UpdateScriptStatusAsync();
            return;
        }

        string? helperExe = FindHelperExe();
        if (!File.Exists(helperExe))
        {
            loadingLabel.Text = "DEX_Helper.exe was not found. Build HelperServer first.";
            return;
        }
        string helperDir = Path.GetDirectoryName(helperExe)!;

        ProcessStartInfo startInfo = new(helperExe)
        {
            WorkingDirectory = helperDir,
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden,
        };
        startInfo.Environment["DEX_HELPER_NO_DIALOG"] = "1";
        helperProcess = Process.Start(startInfo);
        ownsHelper = helperProcess != null;

        for (int i = 0; i < 60; i++)
        {
            if (await IsHelperOnlineAsync())
            {
                await UpdateScriptStatusAsync();
                return;
            }
            await Task.Delay(150);
        }

        loadingLabel.Text = "Helper did not respond on localhost:8080.";
    }

    private async Task UpdateScriptStatusAsync()
    {
        try
        {
            using HttpClient client = new() { Timeout = TimeSpan.FromSeconds(2) };
            string scriptStatus = await client.GetStringAsync("http://localhost:8080/script-status");
            bool ready = scriptStatus.Contains("\"ok\":true", StringComparison.OrdinalIgnoreCase);
            statusLabel.Text = ready
                ? "Helper: active  |  Script: ready"
                : "Helper: active  |  Script: missing";
        }
        catch
        {
            statusLabel.Text = "Helper: active  |  Script: unknown";
        }
    }

    private static string? FindHelperExe()
    {
        DirectoryInfo? current = new(AppContext.BaseDirectory);
        for (int i = 0; i < 8 && current != null; i++, current = current.Parent)
        {
            string candidate = Path.Combine(current.FullName, "HelperServer", "DEX_Helper.exe");
            if (File.Exists(candidate)) return candidate;
        }

        string sibling = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "HelperServer", "DEX_Helper.exe"));
        return File.Exists(sibling) ? sibling : null;
    }

    private static async Task<bool> IsHelperOnlineAsync()
    {
        try
        {
            using HttpClient client = new() { Timeout = TimeSpan.FromSeconds(1) };
            string text = await client.GetStringAsync("http://localhost:8080/status");
            return text.Contains("Active", StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    private async Task InitializeWebViewAsync()
    {
        if (!await IsHelperOnlineAsync()) return;

        string userData = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "DEXPlusPlus",
            "WebView2");
        Directory.CreateDirectory(userData);

        CoreWebView2Environment environment = await CoreWebView2Environment.CreateAsync(null, userData);
        await webView.EnsureCoreWebView2Async(environment);
        webView.CoreWebView2.Settings.AreDefaultContextMenusEnabled = true;
        webView.CoreWebView2.Settings.AreDevToolsEnabled = true;
        webView.CoreWebView2.NavigationCompleted += async (_, args) =>
        {
            if (!args.IsSuccess)
            {
                loadingLabel.Visible = true;
                loadingLabel.Text = "Dashboard failed to load. Retrying...";
                await Task.Delay(500);
                webView.CoreWebView2.Reload();
            }
        };
        webView.CoreWebView2.Navigate(DashboardUrl);
        webView.Visible = true;
        loadingLabel.Visible = false;
    }

    private void ToggleMaximize()
    {
        WindowState = WindowState == FormWindowState.Maximized
            ? FormWindowState.Normal
            : FormWindowState.Maximized;
        maximizeButton.Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        using Pen border = new(Color.FromArgb(41, 52, 64), 1);
        e.Graphics.SmoothingMode = SmoothingMode.None;
        e.Graphics.DrawRectangle(border, 0, 0, Width - 1, Height - 1);
    }

    [DllImport("user32.dll")]
    private static extern bool ReleaseCapture();

    [DllImport("user32.dll")]
    private static extern IntPtr SendMessage(IntPtr hWnd, int msg, int wParam, int lParam);
}
