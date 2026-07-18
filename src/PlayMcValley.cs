using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace McValleyLauncher
{
    internal sealed class LauncherForm : Form
    {
        readonly string root = AppDomain.CurrentDomain.BaseDirectory;
        readonly Label status = new Label();
        readonly ProgressBar progress = new ProgressBar();
        readonly Button play = new Button();
        bool skipUpdate;

        internal LauncherForm()
        {
            Text = "McValley";
            ClientSize = new Size(570, 420);
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            BackColor = Color.FromArgb(22, 28, 24);
            ForeColor = Color.White;
            try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }

            PictureBox logo = new PictureBox();
            logo.Location = new Point(210, 18);
            logo.Size = new Size(150, 150);
            logo.SizeMode = PictureBoxSizeMode.Zoom;
            try
            {
                Stream image = Assembly.GetExecutingAssembly().GetManifestResourceStream("McValley.Icon");
                if (image != null) logo.Image = Image.FromStream(image);
            }
            catch { }
            Controls.Add(logo);

            Label title = new Label();
            title.Text = "MCVALLEY";
            title.Font = new Font("Segoe UI", 25, FontStyle.Bold);
            title.TextAlign = ContentAlignment.MiddleCenter;
            title.Location = new Point(20, 166);
            title.Size = new Size(530, 48);
            Controls.Add(title);

            Label server = new Label();
            server.Text = "hitza13.thddns.net:5570  •  Resource Pack อัตโนมัติ";
            server.Font = new Font("Segoe UI", 10, FontStyle.Regular);
            server.ForeColor = Color.FromArgb(174, 205, 174);
            server.TextAlign = ContentAlignment.MiddleCenter;
            server.Location = new Point(20, 212);
            server.Size = new Size(530, 28);
            Controls.Add(server);

            status.Text = "พร้อมเข้าเกม • อัปเดตเฉพาะไฟล์ที่เปลี่ยน";
            status.Font = new Font("Segoe UI", 10, FontStyle.Regular);
            status.ForeColor = Color.Gainsboro;
            status.TextAlign = ContentAlignment.MiddleCenter;
            status.Location = new Point(30, 252);
            status.Size = new Size(510, 28);
            Controls.Add(status);

            progress.Location = new Point(85, 286);
            progress.Size = new Size(400, 12);
            progress.Visible = false;
            Controls.Add(progress);

            play.Text = "▶  เข้าเกม McValley";
            play.Font = new Font("Segoe UI", 15, FontStyle.Bold);
            play.BackColor = Color.FromArgb(49, 158, 75);
            play.ForeColor = Color.White;
            play.FlatStyle = FlatStyle.Flat;
            play.FlatAppearance.BorderSize = 0;
            play.Cursor = Cursors.Hand;
            play.Location = new Point(125, 320);
            play.Size = new Size(320, 60);
            play.Click += async delegate { await UpdateAndPlay(); };
            Controls.Add(play);
            AcceptButton = play;
        }

        async Task UpdateAndPlay()
        {
            if (IsGameRunning())
            {
                MessageBox.Show("เกมเปิดอยู่แล้วครับ", "McValley", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            play.Enabled = false;
            progress.Visible = true;
            progress.Style = ProgressBarStyle.Marquee;
            status.Text = skipUpdate ? "กำลังเปิดเกม..." : "กำลังตรวจสอบอัปเดต...";

            int exitCode = skipUpdate ? 0 : await RunUpdater();
            if (exitCode != 0)
            {
                progress.Visible = false;
                skipUpdate = true;
                play.Enabled = true;
                play.Text = "▶  เข้าเกมเวอร์ชันที่มีอยู่";
                status.Text = "อัปเดตไม่สำเร็จ • กดอีกครั้งเพื่อเข้าเกมเวอร์ชันเดิม";
                return;
            }

            EnsureResourcePack();
            string launcher = Path.Combine(root, "playstardew.exe");
            if (!File.Exists(launcher))
            {
                MessageBox.Show("ไม่พบ playstardew.exe กรุณาติดตั้งใหม่", "McValley", MessageBoxButtons.OK, MessageBoxIcon.Error);
                play.Enabled = true;
                return;
            }

            status.Text = "กำลังเปิด McValley...";
            Process.Start(new ProcessStartInfo(launcher) { WorkingDirectory = root, UseShellExecute = true });
            Application.Exit();
        }

        Task<int> RunUpdater()
        {
            return Task.Run(delegate
            {
                string script = Path.Combine(root, "mcvalley_update.ps1");
                if (!File.Exists(script)) return 1;

                ProcessStartInfo info = new ProcessStartInfo();
                info.FileName = Path.Combine(Environment.SystemDirectory, "WindowsPowerShell\\v1.0\\powershell.exe");
                info.Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"" + script + "\"";
                info.WorkingDirectory = root;
                info.UseShellExecute = false;
                info.CreateNoWindow = true;
                info.RedirectStandardOutput = true;
                info.RedirectStandardError = true;
                info.StandardOutputEncoding = Encoding.UTF8;

                using (Process process = Process.Start(info))
                {
                    string line;
                    while ((line = process.StandardOutput.ReadLine()) != null) UpdateStatus(line);
                    string error = process.StandardError.ReadToEnd();
                    process.WaitForExit();
                    if (process.ExitCode != 0 && error.Length > 0) UpdateText("อัปเดตไม่สำเร็จ: " + error.Trim());
                    return process.ExitCode;
                }
            });
        }

        void UpdateStatus(string line)
        {
            if (!line.StartsWith("STATUS|", StringComparison.Ordinal)) return;
            string[] parts = line.Split('|');
            string key = parts.Length > 1 ? parts[1] : "";
            string detail = parts.Length > 2 ? parts[2] : "";
            if (key == "Checking") UpdateText("กำลังตรวจสอบอัปเดต...");
            else if (key == "Current") UpdateText("เป็นเวอร์ชันล่าสุดแล้ว • กำลังเปิดเกม...");
            else if (key == "Downloading") UpdateText("กำลังโหลดเฉพาะไฟล์ที่เปลี่ยน " + detail);
            else if (key == "Applying") UpdateText("กำลังติดตั้งอัปเดต...");
            else if (key == "Done") UpdateText("อัปเดตเรียบร้อย • กำลังเปิดเกม...");
            else if (key == "ReinstallRequired") UpdateText("เวอร์ชันเก่าเกินไป กรุณาติดตั้งตัวล่าสุด");
            else if (key == "Failed") UpdateText("อัปเดตไม่สำเร็จ: " + detail);
        }

        void UpdateText(string text)
        {
            if (IsDisposed) return;
            BeginInvoke((MethodInvoker)delegate { status.Text = text; });
        }

        bool IsGameRunning()
        {
            foreach (Process process in Process.GetProcessesByName("javaw"))
            {
                try
                {
                    if (process.MainModule.FileName.StartsWith(root, StringComparison.OrdinalIgnoreCase)) return true;
                }
                catch { }
            }
            return false;
        }

        void EnsureResourcePack()
        {
            string pack = Path.Combine(root, "resourcepacks", "stardew_pack.zip");
            if (!File.Exists(pack)) return;
            string options = Path.Combine(root, "options.txt");
            string[] lines = File.Exists(options) ? File.ReadAllLines(options) : new string[0];
            bool found = false;
            for (int i = 0; i < lines.Length; i++)
            {
                if (lines[i].StartsWith("resourcePacks:", StringComparison.Ordinal))
                {
                    lines[i] = "resourcePacks:[\"stardew_pack.zip\"]";
                    found = true;
                }
            }
            if (!found)
            {
                Array.Resize(ref lines, lines.Length + 1);
                lines[lines.Length - 1] = "resourcePacks:[\"stardew_pack.zip\"]";
            }
            File.WriteAllLines(options, lines);
        }
    }

    internal static class Program
    {
        [STAThread]
        static int Main(string[] args)
        {
            if (args.Length == 1 && args[0] == "--check")
            {
                string root = AppDomain.CurrentDomain.BaseDirectory;
                using (Stream icon = Assembly.GetExecutingAssembly().GetManifestResourceStream("McValley.Icon"))
                {
                    return icon != null &&
                           File.Exists(Path.Combine(root, "mcvalley_update.ps1")) &&
                           File.Exists(Path.Combine(root, "playstardew.exe")) &&
                           File.Exists(Path.Combine(root, "mods", "Stardew_9.jar")) &&
                           File.Exists(Path.Combine(root, "resourcepacks", "stardew_pack.zip")) ? 0 : 2;
                }
            }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new LauncherForm());
            return 0;
        }
    }
}
