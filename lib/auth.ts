import NextAuth from 'next-auth';
import GoogleProvider from 'next-auth/providers/google';
import GitHubProvider from 'next-auth/providers/github';
import { upsertUser } from './supabase';

export const authOptions = {
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_ID || '',
      clientSecret: process.env.GOOGLE_SECRET || '',
      allowDangerousEmailAccountLinking: true,
    }),
    GitHubProvider({
      clientId: process.env.GITHUB_ID || '',
      clientSecret: process.env.GITHUB_SECRET || '',
      allowDangerousEmailAccountLinking: true,
    }),
  ],
  pages: {
    signIn: '/login',
  },
  callbacks: {
    async signIn({ user, account, profile }: any) {
      if (!user.email) return false;

      try {
        // Upsert user in Supabase
        await upsertUser(
          user.email,
          user.name,
          account.provider as 'google' | 'github',
          account.providerAccountId,
          user.image
        );
        return true;
      } catch (error) {
        console.error('Error upserting user:', error);
        return false;
      }
    },

    async jwt({ token, user }: any) {
      if (user) {
        token.email = user.email;
        token.name = user.name;
      }
      return token;
    },

    async session({ session, token }: any) {
      if (session.user) {
        session.user.email = token.email;
      }
      return session;
    },
  },
  session: {
    strategy: 'jwt' as const,
    maxAge: 30 * 24 * 60 * 60, // 30 days
  },
};

export const handler = NextAuth(authOptions);
