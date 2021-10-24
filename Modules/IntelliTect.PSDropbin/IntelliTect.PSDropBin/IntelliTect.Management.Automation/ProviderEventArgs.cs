using System;
using System.Management.Automation.Provider;

namespace IntelliTect.Management.Automation
{
    public class ProviderEventArgs<TProvider> : EventArgs
            where TProvider : CmdletProvider
    {
        public ProviderEventArgs( TProvider provider )
        {
            Provider = provider;
        }

        public TProvider Provider { get; private set; }
        // TODO: Move to base generic class of TProvider
        public static event EventHandler<ProviderEventArgs<TProvider>> OnNewInstance = delegate { };

        public static void PublishNewProviderInstance( TProvider sender, ProviderEventArgs<TProvider> eventArgs )
        {
            OnNewInstance( sender, eventArgs );
        }
    }
}